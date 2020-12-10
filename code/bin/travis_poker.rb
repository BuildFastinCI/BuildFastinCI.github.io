require 'travis'
require 'net/http'
require 'csv'
require File.expand_path('../../lib/loading.rb',__FILE__)
require 'activerecord-import'
# Reads in a CSV as first argument. CSV structure login,project,.. as input, and outputs
# login,project,...,num_travisbuilds

@input_csv = ARGV[0]

def travis_builds_for_project(repo, wait_in_s)
  begin
    if(wait_in_s > 128)
      STDERR.puts "We can't wait forever for #{repo}"
      return 0
    elsif(wait_in_s > 1)
      sleep wait_in_s
    end
    repository = Travis::Repository.find(repo)
    return repository.last_build_number.to_i
  rescue Exception => e
    STDERR.puts "Exception at #{repo}"
    STDERR.puts e.message
    if (defined? e.io) && e.io.status[0] == "429"
      STDERR.puts "Encountered API restriction: next call, sleeping for #{wait_in_s*2}"
      return travis_builds_for_project repo, wait_in_s*2
    end
    if e.message.empty?
      STDERR.puts "Empty exception, sleeping for #{wait_in_s*2}"
      return travis_builds_for_project repo, wait_in_s*2
    end
    return 0
  end
end


def analyze_projects_on_travis
  i = 0
  bulk=[]

  Load_repo.where("id>?",0).find_each do |repo|
            last_id = travis_builds_for_project("#{repo.user}/#{repo.repo}", 1)
            if last_id!=0
                
            
            
            repo.last_id=last_id
            repo.save
            end
        
        
    end
    
      
end

    



analyze_projects_on_travis