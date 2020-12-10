require 'find'
require_relative 'repository'
#生成一个txt文件
class FindRepo
    def self.traverse_dir(dir_path, level, pom_list, gradle_list)
        return if level <= 0
        Dir.foreach(dir_path) do |file|
            if file == "." || file == ".."
                next
            end
            file_path = File.join(dir_path, file)
            #p file_path
            if File.directory? file_path
                traverse_dir(file_path, level - 1, pom_list, gradle_list)
            else
               if file == "pom.xml"
                   pom_list << file_path
               elsif file == "build.gradle"
                   gradle_list << file_path
               end
            end
            #Dir.foreach(dir_path+"/"+file) do |file_name|
            #end
        end
    end

    def self.scan
        Repository.where("tool = 1").find_each do |repo|
            repo_name = repo.repo_name.gsub('/', '@')
            dir_path = File.expand_path(File.join('..', '..', 'sequence', 'repository', repo_name), File.dirname(__FILE__))
            mark = 0
            if File.directory? dir_path
                p dir_path
                pom_list = []
                gradle_list = []
                traverse_dir(dir_path, 3, pom_list, gradle_list)
                if pom_list.size > 0
                    mark = 1
                end
            end
            repo.maven = mark
            repo.save
        end
    end

    def self.test
        dir_path = "/Users/zhangchen/projects/sequence/repository/JakeWharton@ActionBarSherlock"
        pom_list = []
        gradle_list = []
        traverse_dir(dir_path, 3, pom_list, gradle_list)
        p pom_list
        p gradle_list
    end
    
end
#FindRepo::test
FindRepo.scan