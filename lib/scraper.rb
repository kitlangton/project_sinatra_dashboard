require_relative 'job'
require_relative 'job_saver'
require_relative 'filter'

class DiceScraper
  attr_reader :jobs

  ID_REGEX = /\/([^\/]+)\/([^\/]+?)\?icid/

  def initialize(location)
    @location = location
    @agent = Mechanize.new do |agent|
      agent.user_agent_alias = "Mac Safari"
      agent.history_added = Proc.new { sleep 0.5 }
    end
    @jobs = []
  end

  def location_uri
    city = @location['city'].split(" ").join("_")
    state = @location['region_code']
    "#{city}%2C_#{state}"
  end

  def search_for(query)
    query = query.split(" ").join("+")
    search_page(query)
  end

  def search_page(query, page = 1)
    @agent.get("https://www.dice.com/jobs/q-#{query}-l-#{location_uri}-radius-40-limit-30-startPage-#{page}-limit-30-jobs")
  end

  def scrape_jobs(query)
    page = search_for(query)
    count = 1
    # until error_page?(page)
      puts "Searching page # #{count}"
      job_nodes = get_job_nodes(page)
      job_nodes.each do |job_node|
        new_job = job_from_node(job_node)
        @jobs << new_job
      end
      # count += 1
      # page = search_page(query, count)
    # end
    @jobs
  end

  def error_page?(page)
    page = @agent.get(page)
    !!page.at(".err_p")
  end

  def get_job_nodes(page)
    page.css(".col-md-9 > #serp > .serp-result-content")
  end

  def job_from_node(job_node)
    title = job_node.at("h3 a").attributes["title"].value # job title
    company = job_node.at(".employer .hidden-md a").text # company name
    link = job_node.at("h3 a").attributes["href"].value # link to posting on dice
    location = job_node.at(".location").text # location
    date = Chronic.parse(job_node.at(".posted").text) # date of posting
    matches = link.match(ID_REGEX)
    if matches
      company_id, job_id = matches.captures
    else
      raise "Can't find job_id or company_id in #{link}"
    end
    Job.new(title: title, company: company, link: link, location: location, date: date, company_id: company_id, job_id: job_id)
  end
end
