# frozen_string_literal: true

module Studs
  class DropdownComponent < ViewComponent::Base
    SHARED_MENU_CLASSES = "dropdown-menu absolute left-0 z-50 mt-2 max-h-72 overflow-y-auto rounded-none border shadow-lg backdrop-blur-md hidden".freeze
    SHARED_MENU_STYLE = "border-color: rgb(63 63 70); background-color: rgba(24, 24, 27, 0.97); box-shadow: 0 0 0 1px color-mix(in srgb, var(--studs-accent) 90%, transparent), 0 0 32px color-mix(in srgb, var(--studs-accent) 52%, transparent), 0 14px 34px rgba(0, 0, 0, 0.48);".freeze
    SHARED_ITEM_CLASSES = "dropdown-item block w-full px-4 py-2 text-left text-sm text-zinc-200 transition hover:bg-zinc-800/60 data-[selected=true]:bg-zinc-800/70".freeze

    VARIANTS = {
      dashboard_view: {
        width: "w-auto",
        menu_width: "min-w-[6.5rem]",
        button: [
          "studs-nav-btn",
          "justify-between focus:outline-none focus:ring-2 transition-all"
        ].join(" "),
        button_style: "--tw-ring-color: var(--studs-accent);",
        label: "block w-full text-left text-inherit"
      },
      agenda_filter: {
        width: "w-full",
        wrapper: "relative block w-full dropdown-wrapper",
        button: [
          "justify-between rounded-xl border bg-zinc-900/50 px-3 py-2 text-sm text-zinc-200",
          "focus:outline-none focus:ring-2 transition-all"
        ].join(" "),
        button_style: "border-color: var(--studs-border); --tw-ring-color: var(--studs-accent);"
      },
      duration: {
        width: "w-full",
        wrapper: "relative block w-full dropdown-wrapper",
        button: [
          "justify-between rounded-2xl px-4 py-2.5 text-sm text-zinc-100 placeholder:text-zinc-600",
          "bg-zinc-950/60 focus:outline-none focus:ring-2 transition-all duration-150 border"
        ].join(" "),
        button_style: "border-color: var(--studs-border); --tw-ring-color: var(--studs-accent);"
      },
      analytics_compare: {
        width: "w-full",
        wrapper: "relative block w-full dropdown-wrapper",
        button: [
          "w-full rounded-xl px-3 py-2.5 text-sm font-medium text-zinc-100 cursor-pointer focus:outline-none"
        ].join(" "),
        button_style: "background-color: var(--studs-panel-bg); border: 1px solid var(--studs-border);"
      }
    }.freeze

    def initialize(label:, items:, name: "dropdown", selected_value: nil, variant: :duration)
      @label = label
      @items = items
      @name = name
      @selected_value = selected_value
      @variant = VARIANTS.fetch(variant, VARIANTS[:duration])
    end

    def button_classes
      [
        "dropdown-toggle inline-flex items-center justify-between gap-2",
        @variant[:button],
        @variant[:width],
        "disabled:opacity-50 disabled:cursor-not-allowed"
      ].join(" ")
    end

    def wrapper_classes = @variant[:wrapper] || "relative inline-block dropdown-wrapper"
    def button_style = @variant[:button_style]
    def label_classes = "dropdown-label #{@variant[:label] || 'block w-full text-left text-zinc-200'}"

    def show_arrow? = @variant.fetch(:show_arrow, true)
    def arrow_classes = @variant[:arrow] || "dropdown-arrow h-4 w-4 text-zinc-400 transition-transform"

    def menu_classes = [ SHARED_MENU_CLASSES, @variant[:menu_width] || @variant[:width] ].join(" ")
    def menu_style = SHARED_MENU_STYLE
    def item_classes = SHARED_ITEM_CLASSES

    def item_data(item)
      value = item_value(item)
      {
        action: "click->dropdown#select",
        selected: selected?(value),
        dropdown_label_param: item[:label],
        dropdown_value_param: value
      }
    end

    def display_label = selected_item&.fetch(:label, @label) || @label

    private

    def item_value(item) = item[:value] || item[:label]
    def selected?(value) = @selected_value.present? && value.to_s == @selected_value.to_s

    def selected_item
      @selected_item ||= @items.find { |item| !item[:divider] && selected?(item_value(item)) }
    end
  end
end
