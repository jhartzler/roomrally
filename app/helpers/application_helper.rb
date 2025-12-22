module ApplicationHelper
  def lucide_icon(name, options = {})
    options[:class] = [ "lucide", "lucide-#{name}", options[:class] ].compact.join(" ")
    tag.i(**options)
  end
end
