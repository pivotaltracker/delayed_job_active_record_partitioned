require "active_record"
require "delayed_job"
require "delayed/backend/partitioned"

Delayed::Worker.backend = :partitioned
