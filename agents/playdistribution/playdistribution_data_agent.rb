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

class PlaydistributionMailer < ActionMailer::Base

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
        if Rails.env != "development"
          PlaydistributionProductDetail.destroy_all rescue ""
          begin
            Net::FTP.open($site_details["server_domain_name"], $site_details["server_username"], $site_details["server_password"]) do |ftp|
              ftp.passive = true
              $logger.info " Files Started Transfer from server to folder"
              ftp.getbinaryfile("#{$site_details["playdistribution_input_ftp_file_name"]}", "#{Rails.root}/agents/playdistribution/playdistribution_data/#{$site_details["playdistribution_input_ftp_file_name"]}",1024)
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

        @vendor_file = open("#{File.dirname(__FILE__)}/playdistribution_data/#{$site_details["playdistribution_input_file_name"]}",{:ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE})
        @csv_string= @vendor_file.read.encode!("UTF-8", "iso-8859-1", invalid: :replace)

        @p_code = []
        CSV.parse(@csv_string, :headers => true, liberal_parsing: true).each_with_index do |r,i|
          @p_code << r[0]
        end
        brand_url = "https://www.playdistribution.com/ourbrands/"
        doc1 = Nokogiri::HTML(open(brand_url))
        temp_1 = doc1.css("a.button_dark")
        temp_1.each do |t_1|

          @i = 1
          num = 2

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
                        puts  brand = temp_3.css("div#tab-product_brand_tab-content h3").text.strip() rescue ""
                        description = temp_3.css("div#tab-description").text.strip() rescue ""
                        description_html = temp_3.css("div#tab-description").to_s.strip() rescue ""
                        temp_4 = doc.css("div.product_image_wrapper.column.one-second img")
                        t_im =  []
                        temp_4.each do |t_4|
                          t_im << t_4.attr("src") rescue ""
                        end
                        puts image = t_im.uniq.join(", ") rescue ""
                        # csv << ["Detail URL","Sku","brand","title","description_html","description","image"]
                        puts "-----"

                        PlaydistributionDetail.create(:url => detail_url,:vendor_code => sku, :title => title, :description_html => description_html, :description => description, :image => image)
                        $logger.info "Inserted #{detail_url}"
                      end
                    rescue Exception => e
                      begin
                        PlaydistributionDetail.create(:url => detail_url)
                        $logger.info "Inserted #{detail_url}"
                      rescue
                      end
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
        write_data_to_file()
      end
    rescue Exception => e
      $logger.error "Error Occured - #{e.message}"
      $logger.error e.backtrace
      sleep 10
    ensure
      $logger.close
      #~ #Our program will automatically will close the DB connection. But even making sure for the safety purpose.
      ActiveRecord::Base.clear_active_connections!
    end
  end

  def write_data_to_file
    #create excel version of product details
    Dir.mkdir("#{File.dirname(__FILE__)}/playdistribution_data") unless File.directory?("#{File.dirname(__FILE__)}/playdistribution_data")
    # time = DateTime.now.getutc.strftime("%d_%m_%Y_%H_%M_%S") rescue ""
    file_name = "#{$site_details["playdistribution_output_file_name"]}"
    csv = CSV.open(Rails.root.join("#{File.dirname(__FILE__)}", 'playdistribution_data/',file_name), "wb")
    csv << ["ref","Detail URL","Sku","brand","title","description_html","description","image"]
    $logger.info "-added headers--"
    allprods = PlaydistributionDetail.all
    if allprods.length > 0
      allprods.each_with_index do |p_id,counter_row|
        begin
          url = p_id['url']
          sku = p_id['sku']
          title = p_id['title']
          description_html = p_id['description_html']
          description = p_id['description']
          temp_image = p_id['image']
          csv <<  [url ,sku ,title ,description_html ,description ,temp_image]
        rescue
        end
      end
      csv.close
      $logger.info "-xlsx--created locally--"
      # upload_file_to_ftp(file_name)
    else
      puts "Data is not captured"
      csv.close
      send_email= PlaydistributionMailer.alert_data_email()
      send_email.deliver
    end
  end
  def upload_file_to_ftp
    #upload file to ftp
    begin
      file_name = $site_details['playdistribution_output_file_name']
      Net::FTP.open($site_details["server_domain_name"], $site_details["server_username"], $site_details["server_password"]) do |ftp|
        ftp.passive = true
        file_name = $site_details['playdistribution_output_file_name']
        localfile = "#{File.dirname(__FILE__)}/playdistribution_data/#{file_name}"
        remotefile = $site_details['server_output_path']+file_name
        ftp.putbinaryfile(localfile, remotefile, 1024)
        $logger.info "Local Files Transfer"
        files = ftp.list
        $logger.info "Local Files Transferred to FTP - #{files}"
         ftp.delete("#{File.dirname(__FILE__)}/#{$site_details['server_input_path']+$site_details['playdistribution_input_file_name']}") rescue ""
        ftp.close
        # Delete the INPUT file form, Local playdistribution_data
        File.delete("#{Rails.root}/agents/playdistribution/playdistribution_data/#{$site_details['playdistribution_input_file_name']}") rescue ""
        File.delete("#{Rails.root}/agents/playdistribution/playdistribution_data/#{file_name}") rescue "" #deleting  output file from local after sending to FTP
        begin
          job_status = JobStatus.find_or_initialize_by(job_name: $site_details['playdistribution_details']['company_name'])
          job_status.updated_referer = DateTime.now
          job_status.save
        rescue Exception => e
          $logger.error "Error Occured in job status #{e.message}"
          $logger.error e.backtrace
        end
        
      end
    rescue
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