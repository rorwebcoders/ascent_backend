# -*- encoding : utf-8 -*-
require 'logger'
require 'action_mailer'

ActionMailer::Base.raise_delivery_errors = true
ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
  :address              => "smtp.gmail.com",
  :port                 => 587,
  :domain               => "gmail.com",
  :user_name            => "ascentnoreplymailer@gmail.com",
  :password             => "ddzpftmwzygawrxj",
  :authentication       => "plain",
  :enable_starttls_auto => true
}
ActionMailer::Base.view_paths= File.dirname(__FILE__)

class DickerMailer < ActionMailer::Base

  def alert_data_email
    puts "Sending Alert Email.."
    $logger.info "Sending Alert Email.."
    # @q = q
    # @n = n
    # @p = p
    mail(
      :to      => $site_details['email_to'],
      :from    => $site_details['email_from'],
      :subject => "Alert - Error in Ingram - Ascent file."
    ) do |format|
      format.html
    end
  end

  def no_data_alert_mail
    puts "Sending Alert Email.."
    $logger.info "Sending Alert Email.."
    # @q = q
    # @n = n
    # @p = p
    mail(
      :to      => $site_details['email_to'],
      :from    => $site_details['email_from'],
      :subject => "Alert - Error Occured in Ingram - Ascent script."
    ) do |format|
      format.html
    end
  end
end

class DickerDataBuilderAgent
  attr_accessor :options, :errors

  def initialize(options)
    @options = options
    @options
    create_log_file
    establish_db_connection
  end

  def create_log_file
    Dir.mkdir("#{File.dirname(__FILE__)}/logs") unless File.directory?("#{File.dirname(__FILE__)}/logs")
    $logger = Logger.new("#{File.dirname(__FILE__)}/logs/dicker_data_builder_agent.log", 'weekly')
    #~ $logger.level = Logger::DEBUG
    $logger.formatter = Logger::Formatter.new
  end

  def establish_db_connection
    # connect to the MySQL server
    get_db_connection(@options[:env])
  end

  def start_processing
    # Headless.ly do
      begin      
        if $db_connection_established
          Dir.mkdir("#{File.dirname(__FILE__)}/dicker_data") unless File.directory?("#{File.dirname(__FILE__)}/dicker_data")        
          Selenium::WebDriver::Chrome::Service.driver_path = "C:/Chromedriver/chromedriver.exe"
          browser = Watir::Browser.new :chrome#, driver_path: chromedriver_path
          # Selenium::WebDriver::Firefox::Service.driver_path = "/usr/local/bin/geckodriver" # need to specify driver path while running script in cron
          # browser = Watir::Browser.new :firefox        
          browser.window.maximize
          url = "https://portal.dickerdata.co.nz/Account/Login?ReturnUrl=%2Fhome"
          browser.goto "#{url}"
          sleep 5
          user_name = $site_details['dicker_username'] 
          acc_num = $site_details['dicker_acc_num']
          password = $site_details['dicker_password']
          sleep 2
          browser.input(:id => "userName").set user_name
          browser.input(:id => "accountId").set acc_num
          browser.input(:id => "password").set password
          sleep 20
          browser.button(:class => "login_button").click
          sleep 20
          browser.goto("https://portal.dickerdata.co.nz/buy")
          sleep 15
          browser.div(:text => "Browse by Vendors").click
          sleep 20
          doc1 = Nokogiri::HTML(browser.html)                  
          temp_1 = doc1.css("div.logo-footer")
          brand = []
          temp_1.each do |t_1|          
            brand << t_1.text.gsub(" ","") rescue ""          
          end
          puts brand
          brand.each do |brd|
            browser.goto("https://portal.dickerdata.co.nz/buy?brand=#{brd}")
            sleep 5
            
            doc2 = Nokogiri::HTML(browser.html)
            temp_2 = doc2.css("a.ng-tns-c361-0") rescue ""
            temp_2.each_with_index do |t_2,ind| 
              product_url = "https://portal.dickerdata.co.nz"+t_2.attr('href') rescue ""
              exist_data = DickerDetail.where(:url => product_url)           
              if exist_data.count == 0              
                if ind != 0                
                  begin                                    
                    browser.goto(product_url)
                    sleep 5
                    doc3 = Nokogiri::HTML(browser.html)              
                    puts title = doc3.css("div.description-detail")[0].text.strip rescue ""
                    vendor_code = product_url.split("?").first.split("/").last.gsub("%2F","/") rescue ""
                    product_code = vendor_code                  
                    description = doc3.css("div.product-note").text.strip rescue ""
                    description_html = doc3.css("div.product-note").to_s rescue ""
                    specs = doc3.css("table.product-detail-content-tabs-table").css("tr").map{|e| e.css('td.width-x30').text+': '+e.css('td.spec-info').text.strip}.join("\n") rescue ""
                    specs_html = doc3.css("table.product-detail-content-tabs-table").to_s rescue ""
                    temp_image = doc3.css("img.carousel-img").attr("src").value.gsub("../../","https://portal.dickerdata.co.nz/") rescue ""
                    DickerDetail.create(:url => product_url, :ref_id => product_code,:vendor_code => vendor_code, :title => title, :specs_html => specs_html, :specs => specs, :description_html => description_html, :description => description, :image => temp_image)
                    $logger.info "Inserted #{product_code}"                  
                    sleep 2
                    browser.back
                    sleep 2
                  rescue => e
                    $logger.info "Error #{product_code}"                
                    $logger.info "Error #{product_url}" 
                    $logger.info "Error #{e.message}"                

                  end
                end
              end            
            end          
          end
          write_data_to_file()
          puts output_file_path_and_name = $site_details["dicker_file_name"]
          upload_file_to_ftp(output_file_path_and_name)
        end                         
      rescue Exception => e
        $logger.error "Error Occured - #{e.message}"
        $logger.error e.backtrace
        sleep 10
        send_email= DickerMailer.no_data_alert_mail()
        send_email.deliver
      ensure
        $logger.close
        #~ #Our program will automatically will close the DB connection. But even making sure for the safety purpose.
        ActiveRecord::Base.clear_active_connections!
      end
    # end
  end

  def write_data_to_file()
    #create excel version of product details
    Dir.mkdir("#{File.dirname(__FILE__)}/dicker_data") unless File.directory?("#{File.dirname(__FILE__)}/dicker_data")
    puts output_file_path_and_name = $site_details["dicker_file_name"]
    csv = CSV.open("#{File.dirname(__FILE__)}/dicker_data/#{output_file_path_and_name}", 'wb')    
    csv << ["ref","Detail URL","vendor_code","title","description_html","description","specs_html","specs","image"]
    $logger.info "-added headers--"
    allprods = DickerDetail.all
    if allprods.length > 0
      allprods.each_with_index do |p_id,counter_row|
        # begin
          puts product_code = p_id['ref_id'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          url = p_id['url'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          vendor_code = p_id['vendor_code'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          brand = p_id['brand'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          title = p_id['title'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          description_html = p_id['description_html'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          description = p_id['description'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          specs_html = p_id['specs_html'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          specs = p_id['specs'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          temp_image = p_id['image'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          csv <<  [product_code ,url ,vendor_code ,title ,description_html ,description,specs_html,specs,temp_image]
        # rescue
        # end
      end
      csv.close
      $logger.info "-xlsx--created locally--"
      upload_file_to_ftp(output_file_path_and_name)
    else
      puts "Data is not captured"
      csv.close
      Write a code to send alert email to me and you
      send_email= DickerMailer.alert_data_email()
      send_email.deliver
    end
  end  
  def upload_file_to_ftp(output_file_path_and_name)
    begin    
      Net::FTP.open($site_details["server_domain_name"], $site_details["server_username"], $site_details["server_password"]) do |ftp|                
        ftp.passive = true                    
        output_filename = "#{File.dirname(__FILE__)}/dicker_data/#{output_file_path_and_name}"
        remotefile_output_path = $site_details['server_output_path']+output_filename.split("/").last
        ftp.putbinaryfile("agents/dicker/#{output_filename.gsub("./","")}", remotefile_output_path, 1024)
        $logger.info "Local Files Transfer"
        files = ftp.list
        $logger.info "Local Files Transferred to FTP - #{files}"
        #Moved input and output ftp files to archive  path    
        ftp.rename($site_details['server_output_path']+output_filename.split("/").last, $site_details['server_archive_path']+output_filename.split("/").last)
        #Moved input and output ftp files to archive  path
        ftp.close
        # Delete the INPUT file form, Local dicker_data
        File.delete("agents/dicker/#{output_filename.gsub("./","")}") rescue "" #deleting  output file from local after sending to FTP
        begin
          job_status = JobStatus.find_or_initialize_by(job_name: $site_details['dicker_details']['company_name'])
          job_status.updated_referer = DateTime.now
          job_status.save
        rescue Exception => e
          $logger.error "Error Occured in job status #{e.message}"
          $logger.error e.backtrace
        end
      end
    rescue Exception => e
      $logger.error "Error Occured in uploading file #{e.message}"
      $logger.error e.backtrace
    end
  end
end #class

require 'rubygems'
require 'optparse'
options = {}
optparse = OptionParser.new do|opts|
  # Set a banner, displayed at the top
  # of the help screen.
  opts.banner = "Usage: ruby dicker_data_agent.rb [options]"

  # Define the options, and what they do
  options[:action] = 'start'
  opts.on( '-a', '--action ACTION', 'It can be start, stop, restart' ) do |action|
    options[:action] = action
  end

  options[:env] = 'development'
  opts.on( '-e', '--env ENVIRONMENT', 'Run the new dicker agent for building the projects' ) do |env|
    options[:env] = env
  end

  # This displays the help screen, all programs are
  # assumed to have this option.
  opts.on( '-h', '--help', 'To get the list of available options' ) do
    puts opts
    exit
  end
end
optparse.parse!
puts @options = options
require File.expand_path('../load_configurations', __FILE__)
newprojects_agent = DickerDataBuilderAgent.new(options)
newprojects_agent.start_processing
