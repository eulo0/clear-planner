# frozen_string_literal: true

module Studs
  class SearchBarComponent < ::ViewComponent::Base
    # Visual variants, mirroring Studs::DropdownComponent's VARIANTS pattern.
    # Only the bits that differ between looks live here; shared structure stays
    # in #input_classes. :boxed is the default so existing call sites are
    # unchanged; :pill matches the rounded toolbar pills (e.g. Tasks page).
    VARIANTS = {
      boxed: "rounded-xl bg-zinc-900/50 pr-3",
      pill:  "rounded-full bg-[var(--studs-panel-bg-2)] pr-4"
    }.freeze

    def initialize(name: "q", value: nil, placeholder: "Search…", variant: :boxed, class_name: nil, input_class_name: nil, **attrs)
      @name             = name
      @value            = value
      @placeholder      = placeholder
      @variant          = VARIANTS.fetch(variant, VARIANTS[:boxed])
      @class_name       = class_name
      @input_class_name = input_class_name
      @attrs            = attrs
    end

    def wrapper_classes
      [ "relative", @class_name ].compact.join(" ")
    end

    def input_classes
      [
        "w-full border pl-10 py-2 text-sm text-zinc-100 placeholder:text-zinc-500",
        "focus:outline-none focus:ring-2 transition-all",
        @variant,
        @input_class_name
      ].compact.join(" ")
    end

    def input_style
      "border-color: var(--studs-border); --tw-ring-color: var(--studs-accent);"
    end
  end
end
