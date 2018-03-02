Gem::Specification.new do |spec|
  spec.add_dependency "activerecord", [">= 3.0", "< 5"]
  spec.add_dependency "delayed_job",  [">= 3.0", "< 5"]
  spec.authors        = ["Matthew Conger-Eldeen", "Cody Sehl"]
  spec.description    = "Partitioned backend for Delayed::Job"
  spec.email          = ["mcongereldeen@pivotal.io", "csehl@pivotal.io"]
  spec.files          = %w(CONTRIBUTING.md LICENSE.md README.md delayed_job_active_record.gemspec) + Dir["lib/**/*.rb"]
  spec.homepage       = "http://github.com/pivotaltracker/delayed_job_active_record_partioned"
  spec.licenses       = ["MIT"]
  spec.name           = "delayed_job_partitioned"
  spec.require_paths  = ["lib"]
  spec.summary        = "Partitioned backend for DelayedJob"
  spec.version        = "0.0.3"
end
