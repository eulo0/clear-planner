# frozen_string_literal: true

class TasksController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

  def index
    load_board
  end

  def new
    redirect_to tasks_path
  end

  def create
    @task = current_user.tasks.new(task_params)
    if @task.save
      redirect_to tasks_path, status: :see_other, notice: "Task created."
    else
      load_board
      render :index, status: :unprocessable_entity
    end
  end

  def edit
    @task = current_user.tasks.includes(:course_item).find(params[:id])
    render partial: "tasks/edit_drawer",
           locals: { task: @task, courses: courses_for_select, grouped_course_items: grouped_course_items_for_js }
  end

  def update
    @task = current_user.tasks.includes(:course_item).find(params[:id])
    if @task.update(task_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.action("refresh") }
        format.html { redirect_to tasks_path, status: :see_other, notice: "Task updated." }
      end
    else
      render partial: "tasks/edit_drawer",
             locals: { task: @task, courses: courses_for_select, grouped_course_items: grouped_course_items_for_js },
             status: :unprocessable_entity
    end
  end

  def destroy
    current_user.tasks.find(params[:id]).destroy!
    redirect_to tasks_path, status: :see_other, notice: "Task deleted."
  end

  def toggle
    task = current_user.tasks.find(params[:id])
    if task.done?
      task.update!(done: false, completed_at: nil)
    else
      task.update!(done: true, completed_at: Time.current)
    end
    head :ok
  end

  private

  def load_board
    board = Tasks::Board.new(
      current_user,
      q: params[:q],
      status: params[:status],
      course_id: params[:course_id]
    ).call

    @courses                 = board.courses
    @groups                  = board.groups
    @all_tasks               = board.all_tasks
    @missed_tasks            = board.missed_tasks
    @counts                  = board.counts
    @grouped_course_items    = grouped_course_items_for_js
  end

  def courses_for_select
    current_user.courses.order(:title).map { |c| { id: c.id.to_s, name: c.title } }
  end

  def grouped_course_items_for_js
    current_user.courses.includes(:course_items).order(:title).each_with_object({}) do |course, h|
      h[course.id.to_s] = course.course_items.sort_by(&:title).map { |ci|
        { label: ci.title, value: ci.id.to_s }
      }
    end
  end

  def task_params
    params.require(:task).permit(:title, :description, :duration_minutes, :scheduled_at, :course_item_id)
  end
end
