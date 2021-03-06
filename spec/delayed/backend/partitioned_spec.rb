require "helper"
require "delayed/backend/partitioned"

describe Delayed::Backend::Partitioned::Job do
  it_behaves_like "a delayed_job backend"

  describe "reserve_with_scope" do
    let(:worker) { double(name: "worker01", read_ahead: 1) }
    let(:scope)  { double(limit: limit, where: double(update_all: nil)) }
    let(:limit)  { double(job: job) }
    let(:job)    { double(id: 1) }

    before do
      allow(Delayed::Backend::Partitioned::Job.connection).to receive(:adapter_name).at_least(:once).and_return(dbms)
    end

    context "for a dbms without a specific implementation" do
      let(:dbms) { "OtherDB" }

      it "uses the plain sql version" do
        expect(Delayed::Backend::Partitioned::Job).to receive(:reserve_with_scope_using_default_sql).once
        Delayed::Backend::Partitioned::Job.reserve_with_scope(scope, worker, Time.now)
      end
    end
  end

  context "db_time_now" do
    after do
      Time.zone = nil
      ActiveRecord::Base.default_timezone = :local
    end

    it "returns time in current time zone if set" do
      Time.zone = "Eastern Time (US & Canada)"
      expect(%(EST EDT)).to include(Delayed::Job.db_time_now.zone)
    end

    it "returns UTC time if that is the AR default" do
      Time.zone = nil
      ActiveRecord::Base.default_timezone = :utc
      expect(Delayed::Backend::Partitioned::Job.db_time_now.zone).to eq "UTC"
    end

    it "returns local time if that is the AR default" do
      Time.zone = "Central Time (US & Canada)"
      ActiveRecord::Base.default_timezone = :local
      expect(%w(CST CDT)).to include(Delayed::Backend::Partitioned::Job.db_time_now.zone)
    end
  end

  describe "after_fork" do
    it "calls reconnect on the connection" do
      expect(ActiveRecord::Base).to receive(:establish_connection)
      Delayed::Backend::Partitioned::Job.after_fork
    end
  end

  describe "enqueue" do
    it "allows enqueue hook to modify job at DB level" do
      later = described_class.db_time_now + 20.minutes
      job = Delayed::Backend::Partitioned::Job.enqueue payload_object: EnqueueJobMod.new
      expect(Delayed::Backend::Partitioned::Job.find(job.id).run_at).to be_within(1).of(later)
    end
  end

  describe '.reserve' do
    context 'with a custom queueing function' do
      let(:dbms) { "OtherDB" }

      let(:worker) { TestWorker.new("worker01", 5) }

      before do
        allow(Delayed::Backend::Partitioned::Job.connection).to receive(:adapter_name).at_least(:once).and_return(dbms)
      end

      after do
        Delayed::Backend::Partitioned::Job.delete_all
      end

      before do
        Delayed::Worker.queues = lambda do |query|
          query.where('(queue % 8) = 1')
        end
      end

      it 'includes jobs with queues that fit the pattern' do
        Delayed::Backend::Partitioned::Job.enqueue(SampleJob.new, queue: '9')
        expect(Delayed::Backend::Partitioned::Job.reserve(worker).queue).to eq('9')
      end

      it 'excludes jobs that do not fit the pattern' do
        Delayed::Backend::Partitioned::Job.enqueue(SampleJob.new, queue: '8')
        expect(Delayed::Backend::Partitioned::Job.reserve(worker)).to eq(nil)
      end
    end
  end

  if ::ActiveRecord::VERSION::MAJOR < 4 || defined?(::ActiveRecord::MassAssignmentSecurity)
    context "ActiveRecord::Base.send(:attr_accessible, nil)" do
      before do
        Delayed::Backend::Partitioned::Job.send(:attr_accessible, nil)
      end

      after do
        Delayed::Backend::Partitioned::Job.send(:attr_accessible, *Delayed::Backend::Partitioned::Job.new.attributes.keys)
      end

      it "is still accessible" do
        job = Delayed::Backend::Partitioned::Job.enqueue payload_object: EnqueueJobMod.new
        expect(Delayed::Backend::Partitioned::Job.find(job.id).handler).to_not be_blank
      end
    end
  end

  context "ActiveRecord::Base.table_name_prefix" do
    it "when prefix is not set, use 'delayed_jobs' as table name" do
      ::ActiveRecord::Base.table_name_prefix = nil
      Delayed::Backend::Partitioned::Job.set_delayed_job_table_name

      expect(Delayed::Backend::Partitioned::Job.table_name).to eq "partitioned_jobs"
    end

    it "when prefix is set, prepend it before default table name" do
      ::ActiveRecord::Base.table_name_prefix = "custom_"
      Delayed::Backend::Partitioned::Job.set_delayed_job_table_name

      expect(Delayed::Backend::Partitioned::Job.table_name).to eq "custom_partitioned_jobs"

      ::ActiveRecord::Base.table_name_prefix = nil
      Delayed::Backend::Partitioned::Job.set_delayed_job_table_name
    end
  end
end


TestWorker = Struct.new(:name, :read_ahead)

class SampleJob
  def perform
    # noop
  end
end
