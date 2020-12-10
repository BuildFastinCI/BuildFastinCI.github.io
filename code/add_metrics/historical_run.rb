#puts File.expand_path('../../fix_sql.rb',__FILE__)
require File.expand_path('../../fix_sql.rb',__FILE__)
require File.expand_path('../../bin/parse_error_file.rb',__FILE__)
require File.expand_path('../../bin/error_modified.rb',__FILE__)
# require File.expand_path('../../bin/maven_compilation.rb',__FILE__)
require File.expand_path('../../bin/maven_test.rb',__FILE__)
require File.expand_path('../../bin/diff_test.rb',__FILE__)
require File.expand_path('../../lib/all_repo_data_virtual_prior_merge.rb',__FILE__)

require File.expand_path('../../add_new_metric.rb',__FILE__)
require File.expand_path('../current_build.rb',__FILE__)
require File.expand_path('../historical.rb',__FILE__)
require File.expand_path('../historical2.rb',__FILE__)
require File.expand_path('../cll.rb',__FILE__)




def run(user=0,repo=0) 

    # hc=HistoricalConnction2.new(user,repo)
    # hc.update_fail_build_rate
    
    # hc.update_fail_ratio_com_pr
    # hc.update_fail_ratio_com_re
    # hc.pr_src_files
    # hc.pr_src_files_in
    

    # hc.log_src_files
    # hc.log_src_files_in
    hc= HistoricalConnect.new(user,repo)
    hc.update_commiter_exp
end
def write_file_add(contents,parent_dir)
  #json_file = File.join(parent_dir, filename)
  if contents.class == Array
    
      contents.flatten!
  # Remove empty entries
      contents.reject! { |c| c.empty? }
  end
  if File.exists? parent_dir
    #puts "all_commit:#{all_commits}"
    
  
    
  # Remove empty entries
    
    #puts "initial builds size #{contents.size}"
    if contents.empty?
      error_message = "Error could not get any repo information for #{parent_dir}."
      puts error_message    
      exit(1)
    end
  
    File.open(parent_dir, 'a') do |f|
    f.puts(JSON.dump(contents)) 
    end
  
  else
    File.open(parent_dir, 'a') do |f|
    f.puts JSON.dump(contents)
    end
  end

    
end

def method_name
  # parent_dir = File.expand_path('../../new_reponame.txt',__FILE__)
  parent_dir = File.expand_path('../../repo_name.txt',__FILE__)
    repo_name=IO.readlines(parent_dir)
    i=0
    repo_name.each do |line|
        line = JSON.parse(line)
        ActiveRecord::Base.clear_active_connections!
        puts line
        user=line.split('/').first
        repo=line.split('/').last
        
        if i>=0
           run(user,repo)
           
          
        end
        i=i+1
       
        

       
       
    end
end
method_name
  
  #run(owner,repo)

  #SELECT last_label,filesmodified,line_added,line_deleted,src_modified,num_author,failed_build_rate,time_diff,now_label FROM cll_data.all_repo_data_virtual_prior_merges where repo_name='UniversalMediaServer@UniversalMediaServer' order by build_id asc;