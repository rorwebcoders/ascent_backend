# -*- encoding : utf-8 -*-
require 'logger'
require 'action_mailer'

ActionMailer::Base.raise_delivery_errors = true
ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
  :address              => "smtp.gmail.com",
  :port                 => 587,
  :domain               => "gmail.com",
  :user_name            => "itctenders8@gmail.com",
  :password             => "ITCtenders123",
  :authentication       => "plain",
  :enable_starttls_auto => true
}
ActionMailer::Base.view_paths= File.dirname(__FILE__)

class IngramMicroMailer < ActionMailer::Base

  def alert_data_email
    puts "Sending Alert Email.."
    $logger.info "Sending Alert Email.."
    # @q = q
    # @n = n
    # @p = p
    mail(
      :to      => $site_details['email_to'],
      :from    => "itctenders8@gmail.com",
      :subject => "Alert - File does not have data"
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
      :from    => "itctenders8@gmail.com",
      :subject => "Alert - File does not have data"
    ) do |format|
      format.html
    end
  end
end

class IngramMicroDataBuilderAgent
  attr_accessor :options, :errors

  def initialize(options)
    @options = options
    @options
    create_log_file
    establish_db_connection
  end

  def create_log_file
    Dir.mkdir("#{File.dirname(__FILE__)}/logs") unless File.directory?("#{File.dirname(__FILE__)}/logs")
    $logger = Logger.new("#{File.dirname(__FILE__)}/logs/ingram_micro_data_builder_agent.log", 'weekly')
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
        Dir.mkdir("#{File.dirname(__FILE__)}/ingram_micro_data") unless File.directory?("#{File.dirname(__FILE__)}/ingram_micro_data")
        if Rails.env != "development"
          IngramMicroDetail.destroy_all rescue ""
          begin
            Net::FTP.open($site_details["server_domain_name"], $site_details["server_username"], $site_details["server_password"]) do |ftp|
              ftp.passive = true
              $logger.info " Files Started Transfer from server to folder"
              ftp.getbinaryfile($site_details['server_input_path']+$site_details['ingram_micro_input_file_name'], "#{Rails.root}/agents/ingram_micro/ingram_micro_data/"+$site_details['ingram_micro_input_file_name'],1024)
              sleep 5
              $logger.info "Files ended Transfer"
              puts "Files ended Transfer"
              files = ftp.list
              puts files
              ftp.close
            end
          rescue
          end
        end
        # Headless.ly do
        puts @vendor_file="#{File.dirname(__FILE__)}/ingram_micro_data/#{$site_details["ingram_micro_input_file_name"]}"
        if File.exists?(@vendor_file)
          if(File.size(@vendor_file)>0)
            browser = Watir::Browser.new :firefox
            browser.window.maximize
            browser.goto "https://nz.ingrammicro.com/Site/Login"
            browser.text_field(:id=>"okta-signin-username").set($site_details["ingram_micro_username"])
            browser.text_field(:id=>"okta-signin-password").set($site_details["ingram_micro_password"])
            browser.button(:id=>"okta-signin-submit").fire_event :click
            sleep 5
            handler  = File.open(@vendor_file)
            csv_string = handler.read.encode!("UTF-8", invalid: :replace).gsub("\r","")
            CSV.parse(csv_string, :headers => :first_row, liberal_parsing: true, col_sep: "|").each_with_index do |line,index|
              product_code = line[0]
              url = "https://nz.ingrammicro.com/site/productdetail?id=#{product_code}"
              exist_data = IngramMicroDetail.where(:url => url)
              if exist_data.count == 0
                begin
                  browser.goto "#{url}"
                  sleep 2
                  doc = Nokogiri::HTML.parse(browser.html)
                  title = doc.css("div.clsProductFullDesc").text.gsub("Less","").strip() rescue ""
                  puts vendor_code = doc.css("div.Top-Sku-VPN-UPC").text.split("VPN:").last.strip().split("SKU:").first.strip() rescue ""
                  description = doc.css("div#collapseZero").text.strip rescue ""
                  description_html = doc.css("div#collapseZero").to_s rescue ""
                  specs = doc.css("div#collapseOne").text rescue ""
                  specs_html = doc.css("div#collapseOne").to_s rescue ""
                  temp_1 = doc.css("div#slide0 img")
                  temp_image = []
                  temp_1.each do |t_1|
                    temp_image << t_1.attr("src").gsub("/300/","/500/") rescue ""
                  end
                  puts temp_image = temp_image.uniq.join(", ")
                  IngramMicroDetail.create(:url => url, :ref_id => product_code,:vendor_code => vendor_code, :title => title, :specs_html => specs_html, :specs => specs, :description_html => description_html, :description => description, :image => temp_image)
                  $logger.info "Inserted #{product_code}"
                rescue
                  begin
                    IngramMicroDetail.create(:url => url, :ref_id => product_code)
                    $logger.info "Inserted #{product_code}"
                  rescue
                  end
                end
              end
            end
            # end #headless end
            write_data_to_file()
          else
            # send_email= IngramMicroMailer.no_data_alert_mail()
            # send_email.deliver
          end
        end
      end
    rescue Exception => e
      $logger.error "Error Occured - #{e.message}"
      $logger.error e.backtrace
      sleep 10
      # Write a code to send alert email to me and you
    ensure
      $logger.close
      #~ #Our program will automatically will close the DB connection. But even making sure for the safety purpose.
      ActiveRecord::Base.clear_active_connections!
    end
  end

  def write_data_to_file
    #create excel version of product details
    Dir.mkdir("#{File.dirname(__FILE__)}/ingram_micro_data") unless File.directory?("#{File.dirname(__FILE__)}/ingram_micro_data")
    # time = DateTime.now.getutc.strftime("%d_%m_%Y_%H_%M_%S") rescue ""
    file_name = "#{$site_details["ingram_micro_output_file_name"]}"
    csv = CSV.open(Rails.root.join("#{File.dirname(__FILE__)}", 'ingram_micro_data/',file_name), "wb")
    csv << ["ref","Detail URL","vendor_code","title","description_html","description","specs_html","specs","image"]
    $logger.info "-added headers--"
    allprods = IngramMicroDetail.all
    if allprods.length > 0
      allprods.each_with_index do |p_id,counter_row|
        begin
          product_code = p_id['ref_id']
          url = p_id['url']
          vendor_code = p_id['vendor_code']
          brand = p_id['brand']
          title = p_id['title']
          description_html = p_id['description_html']
          description = p_id['description']
          specs_html = p_id['specs_html']
          specs = p_id['specs']
          temp_image = p_id['image']
          csv <<  [product_code ,url ,vendor_code ,title ,description_html ,description,specs_html,specs,temp_image]
        rescue
        end
      end
      csv.close
      $logger.info "-xlsx--created locally--"
      upload_file_to_ftp
    else
      puts "Data is not captured"
      csv.close
      # Write a code to send alert email to me and you
      send_email= IngramMicroMailer.alert_data_email()
      send_email.deliver
    end
  end
  def upload_file_to_ftp
    #upload file to ftp
    begin
      Net::FTP.open($site_details["server_domain_name"], $site_details["server_username"], $site_details["server_password"]) do |ftp|
        ftp.passive = true
        file_name = $site_details['ingram_micro_output_file_name']
        localfile = "#{File.dirname(__FILE__)}/ingram_micro_data/#{file_name}"
        remotefile = $site_details['server_output_path']+file_name
        ftp.putbinaryfile(localfile, remotefile, 1024)
        $logger.info "Local Files Transfer"
        files = ftp.list
        $logger.info "Local Files Transferred to FTP - #{files}"
        #  for now dont use this backup logicc.....
        # ftp.rename($site_details['server_input_path']+$site_details['ingram_micro_input_file_name'], $site_details['server_archive_path']+$site_details['ingram_micro_input_file_name'].gsub(".csv","_#{Date.today.to_s}_#{Time.now.to_i}.csv"))
        # ftp.rename($site_details['server_output_path']+$site_details['ingram_micro_output_file_name'], $site_details['server_archive_path']+$site_details['ingram_micro_output_file_name'].gsub(".csv","_#{Date.today.to_s}_#{Time.now.to_i}.csv"))
        #  for now dont use this backup logicc.....
        
        #once we uploaded file, we need to delete them
        # Delete the INPUT file form, FTP
        # byebug
        ftp.delete("#{File.dirname(__FILE__)}/#{$site_details['server_input_path']+$site_details['ingram_micro_input_file_name']}") rescue ""
        ftp.close
        # Delete the INPUT file form, Local ingram_micro_data
        File.delete("#{Rails.root}/agents/ingram_micro/ingram_micro_data/#{$site_details['ingram_micro_input_file_name']}") rescue ""
        File.delete("#{Rails.root}/agents/ingram_micro/ingram_micro_data/#{file_name}") rescue "" #deleting  output file from local after sending to FTP
        begin
          job_status = JobStatus.find_or_initialize_by(job_name: $site_details['ingram_micro_details']['company_name'])
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
  opts.banner = "Usage: ruby ingram_micro_data_agent.rb [options]"

  # Define the options, and what they do
  options[:action] = 'start'
  opts.on( '-a', '--action ACTION', 'It can be start, stop, restart' ) do |action|
    options[:action] = action
  end

  options[:env] = 'development'
  opts.on( '-e', '--env ENVIRONMENT', 'Run the new ingram_micro agent for building the projects' ) do |env|
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
newprojects_agent = IngramMicroDataBuilderAgent.new(options)
newprojects_agent.start_processing
