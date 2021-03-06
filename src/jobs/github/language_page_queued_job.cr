class Job::Github::LanguagePageQueuedJob < Mosquito::QueuedJob
  include JobSerializers

  params(
    page : Int32 = 1,
    per_page : Int32 = 100,
    pushed_before : Time = Time.utc + Time::Span.new(days: 1)
  )

  def perform
    pushed_before = self.pushed_before <= Time.utc ? self.pushed_before : nil
    return if per_page * page > 1000
    repos = Service::Github.get_by_language(per_page: per_page, page: page, pushed_before: pushed_before)
    repos.each do |repo|
      ProjectUpdateQueuedJob.with_payload(repo).enqueue
    end

    if (last_pushed_repo = repos.reverse.find(&.pushed_at)) && (per_page * page) === 1000
      Job::Github::LanguageIndexPerodicJob.paginate(per_page: per_page, pushed_before: last_pushed_repo.pushed_at.not_nil!)
    end
  end
end
