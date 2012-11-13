#!/usr/bin/env ruby
require "mechanize"
require "highline/import"
require 'ruby-progressbar'

def ScrapeRichting(agent, page, progress_bar, progress_to_do)
  rows = page.parser.xpath('//table[@id="curriculum_study_year_browser_table"]/tbody/tr')
  progress_per_turn = progress_to_do.to_f / rows.size
  progress_done = 0
  rows.each do |row|
    if progress_done > 1
      progress_bar.increment
      progress_done -= 1
    end
    richting = row.at_xpath('td[1]/text()')
    file = File.open("./#{richting}.txt", "w")
    richting_page = agent.get(row.at_xpath('td[2]/div[1]/ul/li/a/@href'))
    
    # Als alle studenten niet op 1 standaard pagina passen
    # => zet ze allemaal op 1 pagina
    if richting_page.forms.size > 0
      richting_page.forms.first.curriculum_student_browser_table_per_page = "all"
      richting_page = richting_page.forms.first.submit
    end
    
    student_rows = richting_page.parser.xpath('//table[@id="curriculum_student_browser_table"]/tbody/tr')

    student_rows_count = student_rows.size
    student_rows.each do |student_row|
        if progress_done > 1
          progress_bar.increment
          progress_done -= 1
        end
        file.write(student_row.at_xpath('td[4]/text()').to_s.strip + "@vub.ac.be\n")     
        progress_done += progress_per_turn/student_rows_count
    end
    
    file.close
  end
end

def start_scraping
  progress_bar = ProgressBar.create(:format => '%a %B %p%% %t')
  agent = Mechanize.new()
  page = agent.get('http://pointcarre.vub.ac.be')
  progress_bar.increment
  # Login
  login_form = page.forms.first
  progress_bar.increment
  login_form.username = @pointcarre_user
  login_form.password = @pointcarre_passwd
  page = agent.submit(login_form, login_form.buttons.first)
  progress_bar.increment
  # Laad paginas met alle richtingen v/d faculteit
  page = agent.get("http://pointcarre.vub.ac.be/run.php?application=curriculum&go=curriculum_total_programs_browser&curriculum_department=#{@department}")
  
  2.times {progress_bar.increment}
  
  page.forms_with(:action => "/run.php").first.curriculum_total_program_browser_table_per_page = "all"
  page = page.forms_with(:action => "/run.php").first.submit
  
  progress_bar.increment
  
  if @richting
    raise TypeError.new "Cannot find a the section #{@richting}" unless agent.page.link_with(:text => @richting)
    progress_bar.increment
    page = agent.page.link_with(:text => @richting).click
    progress_bar.increment
    progress_to_do = progress_bar.total - progress_bar.progress
    ScrapeRichting(agent, page, progress_bar, progress_to_do)
  else
    # Voor elke richting => scrape deze richting
    rows = page.parser.xpath('//table[@id="curriculum_total_program_browser_table"]/tbody/tr')
    progress_to_do = (progress_bar.total - progress_bar.progress)/row.size
    rows.each do |row|
      ScrapeRichting(agent, agent.get(row.at_xpath('td[1]/a/@href')), progress_bar, progress_to_do)
    end
  end
end

@pointcarre_user = ask "Enter you VUB netid"
@pointcarre_passwd = pass = ask("Enter VUB password:  ") { |q| q.echo = "*" }

# Check link van Pointcarre pagina v/d faculteit om departement te achterhalen (WE = 5)
@department = 0
until @department.between? 1, 8 do
  @department = ask("Enter Faculty ID \nHint: LW=1, RC=2, ES=3, PE=4, WE=5, GF=6, IR=7, LK=8").to_i
end 

# Copy-paste van Pointcarre
# OF: nil om alle richtingen te scrapen
#@richting  = "Bachelor of Science in de Computerwetenschappen" 
@richting = ask("Give an optional section, or leave empty for all section within the faculty. 
Hint: Bachelor of Science in de Computerwetenschappen")

#begin
  start_scraping
#rescue TypeError => error
#  puts "Error running script: " + error.message
#rescue StandardError => error
#  puts "Error running script: " + error.message
#end
