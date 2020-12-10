class LogtypeExtract
    
 
    def initialize
        @test_lines = Array.new
        @reactor_lines = []
        @line_marker=0
        @test_section_started=false
        @reactor_started=false
        
    end
    
    def maven_extract(file_array)
        p "maven extract"
        
      file_array.each do |line|
        if !(line =~ /-------------------------------------------------------/).nil? && @line_marker == 0
          @line_marker = 1
        elsif !(line =~ /\[INFO\] Reactor Summary/).nil?
          p "reactor_started"
          @reactor_started = true
          @test_section_started = false
        elsif @reactor_started && (line =~ /\[.*\]/).nil?
          @reactor_started = false
        elsif !(line =~ / T E S T S/).nil? && @line_marker == 1
          @line_marker = 2
        elsif (@line_marker == 1)
          line =~ /Building ([^ ]*)/
          if (!$1.nil? && !$1.strip.empty?)
            current_section = $1
          end
          @line_marker = 0
        elsif !(line =~ /-------------------------------------------------------/).nil? && @line_marker == 2
          @line_marker = 3
          @test_section_started = true
          test_section = current_section
        elsif !(line =~ /-------------------------------------------------------/).nil? && @line_marker == 3
          @line_marker = 0
          @test_section_started = false
        else
          @line_marker = 0
        end
  
        if @test_section_started
          
          @test_lines << line
        
        
        elsif @reactor_started
          @reactor_lines << line
        end
        
      end
      return @test_lines,@reactor_lines
    end
  
    def gradle_extract(file_array)
        
      
    end
    
end
