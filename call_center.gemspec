Gem::Specification.new "call_center", "1.0.4" do |s|
  s.homepage = "http://github.com/zendesk/call_center"
  s.summary = %Q{Support for describing call center workflows}
  s.description = %Q{Support for describing call center workflows}
  s.email = "hhsu@zendesk.com"
  s.authors = ["Henry Hsu"]
  s.license = "Apache License Version 2.0"
  s.add_runtime_dependency "builder"
  s.add_runtime_dependency "state_machine", "~> 1.2.0"
  s.files = `git ls-files lib/`.split("\n")
end

