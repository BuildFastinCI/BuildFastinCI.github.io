#
# (c) 2012 -- 2015 Georgios Gousios <gousiosg@gmail.com>
#

require_relative 'comment_stripper'

module JavaData

  include CommentStripper

  def self.src_file_filter
    lambda { |f|
      path = if f.class == Hash then f[:path] else f end
      path.end_with?('.java')and not test_file_filter.call(f)
    }
  end

  def self.test_file_filter
    lambda { |f|
      path = if f.class == Hash then f[:path] else f end
      path.end_with?('.java') and
          (not path.match(/tests?\//).nil? or not path.match(/[tT]est.java/).nil?)
    }
  end

  def self.filterlog
    lambda { |f|
      path = if f.class == Hash then f[:path] else f end
      
          not path.match(/tests?\//).nil? or not path.match(/[tT]est.java/).nil?
    }
  end
  

  def self.test_case_filter
    lambda do |l|
      not l.match(/@Test/).nil? or
          not l.match(/(public|protected|private|static|\s) +[\w<>\[\]]+\s+(.*[tT]est) *\([^\)]*\) *(\{?|[^;])/).nil?
    end
  end

  def self.assertion_filter
    lambda{|l| not l.match(/assert/).nil?}
  end

  def self.strip_comments(buff)
    strip_c_style_comments(buff)
  end

end
