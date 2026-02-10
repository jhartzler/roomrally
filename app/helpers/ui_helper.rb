module UiHelper
  def ui_button(text, url, variant: :primary, size: :md, **options)
    classes = class_names(
      "inline-flex items-center justify-center font-bold transition-all duration-200 transform border shadow-lg cursor-pointer active:scale-95",
      variant_classes(variant),
      size_classes(size),
      options.delete(:class)
    )

    if block_given?
      link_to(url, options.merge(class: classes)) do
        yield
      end
    elsif url
      link_to(text, url, options.merge(class: classes))
    else
      button_tag(text, options.merge(class: classes))
    end
  end

  def ui_card(**options, &block)
    classes = class_names(
      "bg-white/5 backdrop-blur-md rounded-xl shadow-sm border border-white/10",
      options.delete(:class)
    )

    content_tag(:div, options.merge(class: classes), &block)
  end

  def ui_badge(text, variant: :neutral, **options)
    classes = class_names(
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
      badge_variant_classes(variant),
      options.delete(:class)
    )

    content_tag(:span, text, options.merge(class: classes))
  end

  private

  def variant_classes(variant)
    case variant
    when :primary
      "bg-primary-600 text-white hover:bg-primary-700 hover:shadow-primary-900/40 border-transparent"
    when :secondary
      "bg-secondary-600 text-white hover:bg-secondary-700 hover:shadow-secondary-900/40 border-transparent"
    when :accent
      "bg-accent-500 text-white hover:bg-accent-600 hover:shadow-accent-900/40 border-transparent"
    when :ghost
      "bg-transparent text-primary-100 hover:bg-white/10 border-transparent shadow-none"
    when :gradient
      "bg-gradient-to-r from-secondary-600 to-primary-600 hover:from-secondary-500 hover:to-primary-500 text-white border-white/10"
    else
      "bg-neutral-200 text-neutral-800 hover:bg-neutral-300 border-transparent"
    end
  end

  def size_classes(size)
    case size
    when :sm
      "px-3 py-1.5 text-sm rounded-lg"
    when :md
      "px-6 py-3 text-base rounded-xl"
    when :lg
      "px-8 py-4 text-lg rounded-full"
    when :xl
      "px-12 py-4 text-xl rounded-full"
    end
  end

  def badge_variant_classes(variant)
    case variant
    when :success
      "bg-success-100 text-success-800"
    when :warning
      "bg-warning-100 text-warning-800"
    when :error
      "bg-error-100 text-error-800"
    when :neutral
      "bg-neutral-100 text-neutral-800"
    else
      "bg-primary-100 text-primary-800"
    end
  end
end
