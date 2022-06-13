# -*- encoding : utf-8 -*-
require 'logger'
require 'action_mailer'

ActionMailer::Base.raise_delivery_errors = true
ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
  :address              => "smtp.gmail.com",
  :port                 => 587,
  :domain               => "gmail.com",
  :user_name            => "",
  :password             => "",
  :authentication       => "plain",
  :enable_starttls_auto => true
}
ActionMailer::Base.view_paths= File.dirname(__FILE__)

class SektorMailer < ActionMailer::Base

  def alert_data_email
    puts "Sending Alert Email.."
    $logger.info "Sending Alert Email.."
    mail(
      :to      => $site_details['email_to'],
      :from    => $site_details['email_from'],
      :subject => "Alert - Error in Ascent - Sektor file."
    ) do |format|
      format.html
    end
  end

  def no_data_alert_mail
    puts "Sending Alert Email.."
    $logger.info "Sending Alert Email.."
    mail(
      :to      => $site_details['email_to'],
      :from    => $site_details['email_from'],
      :subject => "Alert - Error Occured in Ascent - Sektor script."
    ) do |format|
      format.html
    end
  end
end

class SektorDataBuilderAgent
  attr_accessor :options, :errors

  def initialize(options)
    @options = options
    @options
    create_log_file
    establish_db_connection
  end

  def create_log_file
    Dir.mkdir("#{File.dirname(__FILE__)}/logs") unless File.directory?("#{File.dirname(__FILE__)}/logs")
    $logger = Logger.new("#{File.dirname(__FILE__)}/logs/sektor_data_builder_agent.log", 'weekly')
    #~ $logger.level = Logger::DEBUG
    $logger.formatter = Logger::Formatter.new
  end

  def establish_db_connection
    # connect to the MySQL server
    get_db_connection(@options[:env])
  end

  def start_processing
    begin
      if $db_connection_established
        Dir.mkdir("#{File.dirname(__FILE__)}/sektor_data") unless File.directory?("#{File.dirname(__FILE__)}/sektor_data")
        SektorProductDetail.destroy_all rescue ""
        if @options[:env] != "development"
          begin
            Net::FTP.open($site_details["server_domain_name"], $site_details["server_username"], $site_details["server_password"]) do |ftp|
              ftp.passive = true
              $logger.info " Files Started Transfer from server to folder"
              ftp.chdir("#{$site_details['server_input_path']}")
              files = ftp.nlst('*.csv')
              files.each do |file|
                puts file
                if file.to_s.starts_with?($site_details['sektor_input_file_name'])
                  ftp.getbinaryfile(file, "#{Rails.root}/agents/sektor/sektor_data/"+file,1024)
                end
              end
              sleep 5
              $logger.info "Files ended Transfer"
              puts "Files ended Transfer"
              ftp.close
            end
          rescue Exception => e
            $logger.error "Error Occured in FTP connection- #{e.message}"
            $logger.error e.backtrace
          end
        end
        Headless.ly do
          all_files =  Dir["#{File.dirname(__FILE__)}/sektor_data/**/*.csv"]
          all_files.each do |input_file_path_and_name|
            begin
              if input_file_path_and_name.to_s.split("/").last.starts_with?($site_details['sektor_input_file_name'])
              if File.exists?(input_file_path_and_name)
                if(File.size(input_file_path_and_name)>0)
                  Selenium::WebDriver::Firefox::Service.driver_path = "/usr/local/bin/geckodriver"
                  browser = Watir::Browser.new :firefox
                  browser.window.maximize
                  workbook = Roo::CSV.new(input_file_path_and_name, csv_options: {encoding: 'iso-8859-1:utf-8'})
                  workbook.default_sheet = workbook.sheets.first
                  ((workbook.first_row + 1)..workbook.last_row).each do |row|
                    begin
                      l = workbook.row(row)[0].gsub(".","-").gsub("#","-").gsub("_","-")
                      $logger.info "Processing #{l}"
                      url = "https://www.sektor.co.nz/Product/#{l}?criteria=#{l}"
                      if(File.exist?("html/#{l}.html"))
                        file = File.read("html/#{l}.html")
                        doc = Nokogiri::HTML(file.to_s)
                      else
                        browser.goto "#{url}"
                        sleep 2
                        doc = Nokogiri::HTML.parse(browser.html)
                        ref_id  = doc.css("div.product-brand").attr("id").to_s.split("brand_").last rescue ""
                        if ref_id == ""
                          sleep 10
                          doc = Nokogiri::HTML.parse(browser.html)
                        end
                      end
                      brand = doc.css("div.brand").text.strip() rescue ""
                      title = doc.css("div.column.small-10 h1").text.strip() rescue ""
                      ref_id  = doc.css("div.product-brand").attr("id").to_s.split("brand_").last rescue ""
                      specs_html =  doc.css("section#specs").to_s rescue ""
                      specs =  doc.css("section#specs").text.strip rescue ""
                      description_html = doc.css("section#description") rescue ""
                      description = doc.css("section#description").text rescue ""
                      short_description = doc.css("div.short-description").text rescue ""
                      image = "https://www.sektor.co.nz"+doc.css("img#mainProductImage").attr("src") rescue ""
                      if doc.css("div.codes").to_s.include?("Stock code:")
                        stock_code = doc.css("div.codes").to_s.split("Stock code:").last.split("</div>").first.strip()
                      end
                      if doc.css("div.codes").to_s.include?("Vendor code:")
                        vendor_code = doc.css("div.codes").to_s.split("Vendor code:").last.split("</div>").first.strip()
                      end
                      temp_2  = doc.css("ul.doclinks li")
                      pdfs = []
                      temp_2.each do |t_2|
                        pdfs << "https://www.sektor.co.nz"+t_2.css("a")[0]["href"]
                      end
                      pdfs = pdfs.join(", ")
                      video  = doc.css("section#video iframe").attr("src") rescue ""
                      exist_data = SektorDetail.where(:url => url)
                      if exist_data.count == 0
                        SektorDetail.create(:url => url, :ref_id => ref_id, :stock_code => stock_code, :vendor_code => vendor_code, :brand => brand, :title => title, :short_description => short_description, :specs_html => specs_html, :specs => specs, :description_html => description_html, :description => description, :image => image, :pdfs => pdfs, :video => video)
                        $logger.info "Inserted #{vendor_code}"
                      end
                    rescue Exception => e
                      begin
                          SektorDetail.create(:url => url, :vendor_code => vendor_code)
                          $logger.info "Inserted #{vendor_code}"
                        rescue
                        end
                      $logger.error "Error Occured in #{url} - #{e.message}"
                      $logger.error e.backtrace
                    end
                  end
                  write_data_to_file(input_file_path_and_name)
                end
              end
            end
            rescue Exception => e
              puts  "Some problem in #{input_file_path_and_name} process Please Check"
            $logger.info  "Some problem in #{input_file_path_and_name} process Please Check - #{e.message}"
            $logger.info  e.backtrace
            end
          end
        end
      end
    rescue Exception => e
      $logger.error "Error Occured - #{e.message}"
      $logger.error e.backtrace
      sleep 10
      send_email= SektorMailer.no_data_alert_mail()
      send_email.deliver
    ensure
      $logger.close
      #~ #Our program will automatically will close the DB connection. But even making sure for the safety purpose.
      ActiveRecord::Base.clear_active_connections!
    end
  end

  def write_data_to_file(input_file_path_and_name)
    #create excel version of product details
    Dir.mkdir("#{File.dirname(__FILE__)}/sektor_data") unless File.directory?("#{File.dirname(__FILE__)}/sektor_data")
    puts output_file_path_and_name = input_file_path_and_name.to_s.gsub("_input_","_output_")
    csv = CSV.open(output_file_path_and_name, "wb")
    csv << ["Detail URL","Reference ID","stock_code","vendor_code","brand","title","short_description","specs_html","specs","description_html","description","image","pdfs","videos"]
    $logger.info "-added headers--"
    allprods = SektorDetail.all
    if allprods.length > 0
      allprods.each_with_index do |p_id,counter_row|
        begin
          url = p_id['url'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          ref_id = p_id['ref_id'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          stock_code = p_id['stock_code'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          vendor_code = p_id['vendor_code'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          brand = p_id['brand'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          title = p_id['title'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          short_description = p_id['short_description'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          specs_html = p_id['specs_html'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          specs = p_id['specs'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          description_html = p_id['description_html'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          description = p_id['description'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          image = p_id['image'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          pdfs = p_id['pdfs'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          video = p_id['video'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          csv <<  [url, ref_id, stock_code, vendor_code, brand, title, short_description, specs_html, specs, description_html, description, image, pdfs, video]
        rescue
        end
      end
      csv.close
      $logger.info "-xlsx--created locally--"
      upload_file_to_ftp(input_file_path_and_name,output_file_path_and_name)
    else
      puts "Data is not captured"
      csv.close
      send_email= SektorMailer.alert_data_email()
      send_email.deliver
    end
  end
  def upload_file_to_ftp(input_file_path_and_name,output_file_path_and_name)
    #upload file to ftp
    begin
      Net::FTP.open($site_details["server_domain_name"], $site_details["server_username"], $site_details["server_password"]) do |ftp|
        ftp.passive = true
        input_file_name = input_file_path_and_name.to_s.split("/").last
        output_filename = output_file_path_and_name.to_s.split("/").last
        remotefile_output_path = $site_details['server_output_path']+output_filename
        ftp.putbinaryfile(output_file_path_and_name, remotefile_output_path, 1024)
        $logger.info "Local Files Transfer"
        files = ftp.list
        $logger.info "Local Files Transferred to FTP - #{files}"
        #Moved input and output ftp files to archive  path
        ftp.rename($site_details['server_input_path']+input_file_name, $site_details['server_archive_path']+input_file_name)
        ftp.rename($site_details['server_output_path']+output_filename, $site_details['server_archive_path']+output_filename)
        #Moved input and output ftp files to archive  path
        ftp.close
        # Delete the INPUT file form, Local sektor_data
        File.delete(input_file_path_and_name) rescue ""  #deleting  input file from local after sending to FTP
        File.delete(output_file_path_and_name) rescue "" #deleting  output file from local after sending to FTP
        begin
          job_status = JobStatus.find_or_initialize_by(job_name: $site_details['sektor_details']['company_name'])
          job_status.updated_referer = DateTime.now
          job_status.save
        rescue Exception => e
          $logger.error "Error Occured in job status #{e.message}"
          $logger.error e.backtrace
        end
      end
    rescue Exception => e
      $logger.error "Error Occured in file upload #{e.message}"
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
  opts.banner = "Usage: ruby sektor_data_agent.rb [options]"

  # Define the options, and what they do
  options[:action] = 'start'
  opts.on( '-a', '--action ACTION', 'It can be start, stop, restart' ) do |action|
    options[:action] = action
  end

  options[:env] = 'development'
  opts.on( '-e', '--env ENVIRONMENT', 'Run the new sektor agent for building the projects' ) do |env|
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
newprojects_agent = SektorDataBuilderAgent.new(options)
newprojects_agent.start_processing
