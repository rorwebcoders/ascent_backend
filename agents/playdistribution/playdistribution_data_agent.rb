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

class PlaydistributionMailer < ActionMailer::Base

  def alert_data_email
    puts "Sending Alert Email.."
    $logger.info "Sending Alert Email.."
    # @q = q
    # @n = n
    # @p = p
    mail(
      :to      => $site_details['email_to'],
      :from    => $site_details['email_from'],
      :subject => "Alert - Error in Ascent - PlayDistribution file."
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
      :subject => "Alert - Error Occured in Ascent - PlayDistribution script."
    ) do |format|
      format.html
    end
  end
end

class PlaydistributionDataBuilderAgent
  attr_accessor :options, :errors

  def initialize(options)
    @options = options
    @options
    create_log_file
    establish_db_connection
  end

  def create_log_file
    Dir.mkdir("#{File.dirname(__FILE__)}/logs") unless File.directory?("#{File.dirname(__FILE__)}/logs")
    $logger = Logger.new("#{File.dirname(__FILE__)}/logs/playdistribution_data_builder_agent.log", 'weekly')
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
        Dir.mkdir("#{File.dirname(__FILE__)}/playdistribution_data") unless File.directory?("#{File.dirname(__FILE__)}/playdistribution_data")
        if @options[:env] != "development"
          begin
            Dir.foreach("#{File.dirname(__FILE__)}/playdistribution_data") do |f|
              fn = File.join("#{File.dirname(__FILE__)}/playdistribution_data", f)
              File.delete(fn) if f != '.' && f != '..'
            end
          rescue
          end
          begin
            Net::FTP.open($site_details["server_domain_name"], $site_details["server_username"], $site_details["server_password"]) do |ftp|
              ftp.passive = true
              $logger.info " Files Started Transfer from server to folder"
              ftp.chdir("#{$site_details['server_input_path']}")
              files = ftp.nlst('*.csv')
              files.each do |file|
                puts file
                if file.to_s.starts_with?($site_details['playdistribution_input_file_name'])
                  ftp.getbinaryfile(file, "#{Rails.root}/agents/playdistribution/playdistribution_data/"+file,1024)
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
        all_files =  Dir["#{File.dirname(__FILE__)}/playdistribution_data/**/*.csv"]
        all_files.each do |input_file_path_and_name|
          begin
            if input_file_path_and_name.to_s.split("/").last.starts_with?($site_details['playdistribution_input_file_name'])
              if File.exists?(input_file_path_and_name)
                if(File.size(input_file_path_and_name)>0)
                  write_data_to_file(input_file_path_and_name)
                  PlaydistributionDetail.destroy_all rescue ""
                  @csv_string= (File.open(input_file_path_and_name)).read.encode!("UTF-8", "iso-8859-1", invalid: :replace)
                  @p_code = []
                  CSV.parse(@csv_string, :headers => true, liberal_parsing: true).each_with_index do |r,i|
                    @p_code << r[0]
                  end
                  brand_url = "https://www.playdistribution.com/ourbrands/"
                  doc1 = Nokogiri::HTML(open(brand_url))
                  temp_1 = doc1.css("a.button_dark")
                  temp_1.each do |t_1|
                    @i = 1
                    num = 10
                    while @i < num
                      puts url = "https://www.playdistribution.com"+t_1["href"]+"page/#{@i}/"
                      begin
                        doc2 = Nokogiri::HTML(open(url))
                        temp_2 =  doc2.css("ul.products li.product-type-simple")
                        temp_2.each do |t_2|
                          puts detail_url = t_2.css("a")[0]["href"] rescue ""
                          if detail_url.to_s !=  ""
                            exist_data = PlaydistributionDetail.where(:url => detail_url)
                            if exist_data.count == 0
                              begin
                                doc = Nokogiri::HTML(open(detail_url))
                                temp_3 =  doc.css("div.sections_group")
                                sku = temp_3.css("span.sku").text  rescue ""
                                if (sku.to_s != "" &&  @p_code.include?(sku))
                                  puts sku
                                  title = doc.css("h2.title").text.strip() rescue ""
                                  brand = temp_3.css("div#tab-product_brand_tab-content h3").text.strip() rescue ""
                                  description = temp_3.css("div#tab-description").text.strip() rescue ""
                                  description_html = temp_3.css("div#tab-description").to_s.strip() rescue ""
                                  temp_4 = doc.css("div.product_image_wrapper.column.one-second img")
                                  t_im =  []
                                  temp_4.each do |t_4|
                                    t_im << t_4.attr("src") rescue ""
                                  end
                                  puts image = t_im.uniq.join(", ") rescue ""
                                  PlaydistributionDetail.create(:ref_id=>sku, :url => detail_url, :brand => brand,:vendor_code => sku, :title => title, :description_html => description_html, :description => description, :image => image)
                                  $logger.info "Inserted #{detail_url}"
                                end
                              rescue Exception => e

                              end
                            end
                          end
                        end
                        @i=@i+1
                      rescue
                        @i=@i+10
                      end
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
    rescue Exception => e
      $logger.error "Error Occured - #{e.message}"
      $logger.error e.backtrace
      sleep 10
      send_email= PlaydistributionMailer.no_data_alert_mail()
      send_email.deliver
    ensure
      $logger.close
      #~ #Our program will automatically will close the DB connection. But even making sure for the safety purpose.
      ActiveRecord::Base.clear_active_connections!
    end
  end

  def write_data_to_file(input_file_path_and_name)
    #create excel version of product details
    Dir.mkdir("#{File.dirname(__FILE__)}/playdistribution_data") unless File.directory?("#{File.dirname(__FILE__)}/playdistribution_data")
    puts output_file_path_and_name = input_file_path_and_name.to_s.gsub("_input_","_output_")
    csv = CSV.open(output_file_path_and_name, "wb")
    csv << ["ref","Detail URL","Sku","brand","title","description_html","description","image"]
    $logger.info "-added headers--"
    allprods = PlaydistributionDetail.all
    if allprods.length > 0
      allprods.each_with_index do |p_id,counter_row|
        begin
          puts ref_id = p_id['ref_id'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          url = p_id['url'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          puts sku = p_id['vendor_code'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          puts brand = p_id['brand'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          title = p_id['title'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          description_html = p_id['description_html'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          description = p_id['description'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          temp_image = p_id['image'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          csv <<  [ref_id,url ,sku ,brand,title ,description_html ,description ,temp_image]
        rescue
        end
      end
      csv.close
      $logger.info "-xlsx--created locally--"
      puts "-xlsx--created locally--"
      upload_file_to_ftp(input_file_path_and_name,output_file_path_and_name)
    else
      Net::FTP.open($site_details["server_domain_name"], $site_details["server_username"], $site_details["server_password"]) do |ftp|
        ftp.passive = true
        input_file_name = input_file_path_and_name.to_s.split("/").last
        ftp.rename($site_details['server_input_path']+input_file_name, $site_details['server_archive_path']+"#{input_file_name.gsub('.csv', '_review.csv')}")
      end
      puts "Data is not captured"
      csv.close
      # send_email= PlaydistributionMailer.alert_data_email()
      # send_email.deliver
    end
  end
  def upload_file_to_ftp(input_file_path_and_name,output_file_path_and_name)
    #upload file to ftp
    begin
      Net::FTP.open($site_details["server_domain_name"], $site_details["server_username"], $site_details["server_password"]) do |ftp|
        ftp.passive = true
        # puts output_file_path_and_name
        input_file_name = input_file_path_and_name.to_s.split("/").last
        output_filename = output_file_path_and_name.to_s.split("/").last
        remotefile_output_path = $site_details['server_output_path']+output_filename
        ftp.putbinaryfile(output_file_path_and_name, remotefile_output_path, 1024)
        $logger.info "Local Files Transfer"
        files = ftp.list
        $logger.info "Local Files Transferred to FTP - #{files}"
        #Moved input and output ftp files to archive  path
        ftp.rename($site_details['server_input_path']+input_file_name, $site_details['server_archive_path']+input_file_name)
        #Moved input and output ftp files to archive  path
        ftp.close
        # Delete the INPUT file form, Local playdistribution_data
        File.delete(input_file_path_and_name) rescue ""  #deleting  input file from local after sending to FTP
        File.delete(output_file_path_and_name) rescue "" #deleting  output file from local after sending to FTP
        begin
          job_status = JobStatus.find_or_initialize_by(job_name: $site_details['playdistribution_details']['company_name'])
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
  opts.banner = "Usage: ruby playdistribution_data_agent.rb [options]"

  # Define the options, and what they do
  options[:action] = 'start'
  opts.on( '-a', '--action ACTION', 'It can be start, stop, restart' ) do |action|
    options[:action] = action
  end

  options[:env] = 'development'
  opts.on( '-e', '--env ENVIRONMENT', 'Run the new playdistribution agent for building the projects' ) do |env|
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
newprojects_agent = PlaydistributionDataBuilderAgent.new(options)
newprojects_agent.start_processing
