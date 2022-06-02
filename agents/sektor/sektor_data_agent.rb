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
      :from    => "itctenders8@gmail.com",
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
        if Rails.env != "development"
          SektorProductDetail.destroy_all rescue ""
          begin
            Net::FTP.open($site_details["server_domain_name"], $site_details["server_username"], $site_details["server_password"]) do |ftp|
              ftp.passive = true
              $logger.info " Files Started Transfer from server to folder"
              ftp.getbinaryfile("#{$site_details["sektor_input_ftp_file_name"]}", "#{Rails.root}/agents/sektor/sektor_data/#{$site_details["sektor_input_ftp_file_name"]}",1024)
              $logger.info "Files ended Transfer"
              puts "Files ended Transfer"
              $logger.info "Files Deleted in server"
              puts "Files Deleted in server"
              files = ftp.list
              puts files
              ftp.close
            end
          rescue
          end
        end
        Headless.ly do
        @vendor_file="#{File.dirname(__FILE__)}/sektor_data/#{$site_details["sektor_input_ftp_file_name"]}"
        if File.exists?(@vendor_file)
          if(File.size(@vendor_file)>0)
            Selenium::WebDriver::Firefox::Service.driver_path = "/usr/local/bin/geckodriver"
            browser = Watir::Browser.new :firefox
            browser.window.maximize
            workbook = Roo::CSV.new(@vendor_file, csv_options: {encoding: 'iso-8859-1:utf-8'})
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
                end
              rescue Exception => e
                $logger.error "Error Occured in #{url} - #{e.message}"
                $logger.error e.backtrace
              end
              
            end
            write_data_to_file()
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

  def write_data_to_file
    #create excel version of product details
    Dir.mkdir("#{File.dirname(__FILE__)}/sektor_data") unless File.directory?("#{File.dirname(__FILE__)}/sektor_data")
    file_name = "#{$site_details["sektor_output_file_name"]}"
    csv = CSV.open(Rails.root.join("#{File.dirname(__FILE__)}", 'sektor_data/',file_name), "wb")
    csv << ["Detail URL","Reference ID","stock_code","vendor_code","brand","title","short_description","specs_html","specs","description_html","description","image","pdfs","videos"]
    $logger.info "-added headers--"
    allprods = SektorDetail.all
    if allprods.length > 0
      allprods.each_with_index do |p_id,counter_row|
        begin
          url = p_id['url']
          ref_id = p_id['ref_id']
          stock_code = p_id['stock_code']
          vendor_code = p_id['vendor_code']
          brand = p_id['brand']
          title = p_id['title']
          short_description = p_id['short_description']
          specs_html = p_id['specs_html']
          specs = p_id['specs']
          description_html = p_id['description_html']
          description = p_id['description']
          image = p_id['image']
          pdfs = p_id['pdfs']
          video = p_id['video']
          csv <<  [url, ref_id, stock_code, vendor_code, brand, title, short_description, specs_html, specs, description_html, description, image, pdfs, video]
        rescue
        end
      end
      csv.close
      $logger.info "-xlsx--created locally--"
      upload_file_to_ftp
    else
      puts "Data is not captured"
      csv.close
      send_email= SektorMailer.alert_data_email()
      send_email.deliver
    end
  end
  def upload_file_to_ftp
    #upload file to ftp
    begin
      file_name = "#{$site_details["sektor_output_file_name"]}"
      Net::FTP.open($site_details["server_domain_name"], $site_details["server_username"], $site_details["server_password"]) do |ftp|
        ftp.passive = true
        file_name = $site_details['sektor_output_file_name']
        localfile = "#{File.dirname(__FILE__)}/sektor_data/#{file_name}"
        remotefile = $site_details['server_output_path']+file_name
        ftp.putbinaryfile(localfile, remotefile, 1024)
        $logger.info "Local Files Transfer"
        files = ftp.list
        $logger.info "Local Files Transferred to FTP - #{files}"
        ftp.delete("#{File.dirname(__FILE__)}/#{$site_details['server_input_path']+$site_details['sektor_input_file_name']}") rescue ""
        ftp.close
        # Delete the INPUT file form, Local sektor_data
        File.delete("#{Rails.root}/agents/sektor/sektor_data/#{$site_details['sektor_input_file_name']}") rescue ""
        File.delete("#{Rails.root}/agents/sektor/sektor_data/#{file_name}") rescue "" #deleting  output 
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
