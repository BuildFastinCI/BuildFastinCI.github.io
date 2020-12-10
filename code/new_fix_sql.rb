require 'json'
require 'open-uri'
require 'net/http'
require 'fileutils'
require 'time_difference'
require 'activerecord-import'
require 'travis'
require 'rugged'
require 'thread'
#require_relative 'java'
require File.expand_path('../lib/repo_data_travis.rb',__FILE__)
require File.expand_path('../lib/all_repo_data_virtual_prior_merge.rb',__FILE__)
require File.expand_path('../lib/commit_info.rb',__FILE__)
require File.expand_path('../lib/all_repo_data_virtual.rb',__FILE__)
#require File.expand_path('../commit_extract.rb',__FILE__)
require File.expand_path('../lib/temp_all_virtual_prior_merge.rb',__FILE__)
require File.expand_path('../lib/loading.rb',__FILE__)
require File.expand_path('../lib/file_path.rb',__FILE__)
require File.expand_path('../lib/filemodif_info.rb',__FILE__)
require File.expand_path('../bin/diff_test.rb',__FILE__)
require File.expand_path('../lib/maven_error.rb',__FILE__)
require File.expand_path('../lib/job.rb',__FILE__)
require File.expand_path('../lib/travistorrents.rb',__FILE__)
require File.expand_path('../lib/travis_alldatas.rb',__FILE__)
require File.expand_path('../lib/travis_82_alldata.rb',__FILE__)
require File.expand_path('../lib/travis_1027_alldatas.rb',__FILE__)
require File.expand_path('../lib/build_number.rb',__FILE__)
require_relative 'bin/java'

module NewFixsql
    @thread_number = 30
    def update
        
    end
    
end