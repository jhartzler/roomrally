module ApplicationHelper
  def lucide_icon(name, options = {})
    options[:class] = "lucide lucide-#{name} #{options[:class]}"
    tag.i(**options)
  end
end
