# frozen_string_literal: true

module CanvasSync
  # Reconciles parsed Canvas assignment entries into a user's course_items.
  #   - update existing item by UID
  #   - link onto an exact-title unlinked item (don't touch points)
  #   - otherwise create a source: canvas item
  #   - conservatively delete/unlink ONLY future-dated items absent from the feed
  # Runs in one transaction with CourseItem notifications suppressed.
  class Reconciler
    Result = Struct.new(:created, :updated, :linked, :deleted, :skipped_unmatched,
                        keyword_init: true)

    def self.call(subscription, entries)
      new(subscription, entries).call
    end

    def initialize(subscription, entries)
      @subscription = subscription
      @user = subscription.user
      @entries = entries
    end

    def call
      @result = Result.new(created: 0, updated: 0, linked: 0, deleted: 0, skipped_unmatched: [])
      seen = Hash.new { |h, k| h[k] = [] } # course_id => [uid, ...]

      CourseItem.suppressing_sync_notifications do
        ActiveRecord::Base.transaction do
          @entries.each do |entry|
            course = resolve_course(entry.course_code)
            if course.nil?
              @result.skipped_unmatched << entry.course_code
              next
            end
            seen[course.id] << entry.uid
            apply(course, entry)
          end
          reconcile_deletions(seen)
        end
      end

      @result.skipped_unmatched.uniq!
      @result
    end

    private

    def courses_by_code
      @courses_by_code ||= @user.courses.each_with_object({}) do |course, map|
        key = CanvasSync.normalize_code(course.code)
        map[key] ||= course if key.present?
      end
    end

    def resolve_course(code)
      courses_by_code[CanvasSync.normalize_code(code)]
    end

    def apply(course, entry)
      existing = course.course_items.find_by(canvas_uid: entry.uid)
      if existing
        existing.update!(title: entry.title, due_at: entry.due_at) # never touch points
        @result.updated += 1
        return
      end

      candidate = course.course_items.where(canvas_uid: nil).detect do |item|
        CanvasSync.normalize_title(item.title) == CanvasSync.normalize_title(entry.title)
      end

      if candidate
        candidate.update!(canvas_uid: entry.uid, due_at: entry.due_at) # keep source + points
        @result.linked += 1
      else
        course.course_items.create!(
          canvas_uid: entry.uid, source: :canvas, kind: :assignment,
          title: entry.title, due_at: entry.due_at
        )
        @result.created += 1
      end
    end

    # Conservative: only touch FUTURE-dated items absent from this fetch. A
    # windowed Canvas feed legitimately drops past events — never treat that as
    # a deletion.
    def reconcile_deletions(seen)
      @user.courses.each do |course|
        scope = course.course_items
                      .where.not(canvas_uid: nil)
                      .where("due_at >= ?", Time.current)
        present = seen[course.id]
        scope = scope.where.not(canvas_uid: present) if present.any?

        scope.each do |item|
          if item.source_canvas?
            item.destroy!
            @result.deleted += 1
          else
            item.update!(canvas_uid: nil) # unlink, keep due_at + source
          end
        end
      end
    end
  end
end
