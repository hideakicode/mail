require File.dirname(__FILE__) + '/../spec_helper'

require 'mail'

describe Mail::Header do

  describe "initialization" do
    
    it "should instantiate empty" do
      doing { Mail::Header.new }.should_not raise_error
    end

    it "should instantiate with a string passed in" do
      doing { Mail::Header.new("To: Mikel\r\nFrom: bob\r\n") }.should_not raise_error
    end

  end

  describe "accessor methods" do
    
    it "should save away the raw source of the header that it is passed" do
      header = Mail::Header.new("To: Mikel\r\nFrom: bob\r\n")
      header.raw_source.should == "To: Mikel\r\nFrom: bob\r\n"
    end
    
  end

  describe "parsing" do

    it "should split the header into separate fields" do
      header = Mail::Header.new("To: Mikel\r\nFrom: bob\r\n")
      header.fields.length.should == 2
    end
    
    it "should not split a wrapped header in two" do
      header = Mail::Header.new("To: Mikel\r\n\tLindsaar\r\nFrom: bob\r\nSubject: This is\r\n a long\r\n\t \t \t \t    badly formatted             \r\n       \t\t  \t       field")
      header.fields.length.should == 3
    end
    
    #  Header fields are lines composed of a field name, followed by a colon
    #  (":"), followed by a field body, and terminated by CRLF.  A field
    #  name MUST be composed of printable US-ASCII characters (i.e.,
    #  characters that have values between 33 and 126, inclusive), except
    #  colon.
    it "should accept any valid header field name" do
      test_name = ascii.reject { |c| c == ':' }.join
      doing { Mail::Header.new("#{test_name}: This is a crazy name") }.should_not raise_error
    end

    # A field body may be composed of any US-ASCII characters,
    # except for CR and LF.  However, a field body may contain CRLF when
    # used in header "folding" and  "unfolding" as described in section
    # 2.2.3.
    it "should accept any valid header field value" do
      test_value = ascii.reject { |c| c == ':' }
      test_value << ' '
      test_value << '\r\n'
      doing {Mail::Header.new("header: #{test_value}")}.should_not raise_error
    end
    
    it "should split each field into an name and value" do
      header = Mail::Header.new("To: Mikel\r\nFrom: bob\r\n")
      header.fields[0].name.should == "To"
      header.fields[0].value.should == "Mikel"
      header.fields[1].name.should == "From"
      header.fields[1].value.should == "bob"
    end
    
    it "should preserve the order of the fields it is given" do
      header = Mail::Header.new
      header.fields = ['From: mikel@me.com', 'To: bob@you.com', 'Subject: This is a badly formed email']
      header.fields[0].name.should == 'From'
      header.fields[1].name.should == 'To'
      header.fields[2].name.should == 'Subject'
    end
    
    it "should allow you to reference each field and value by literal string name" do
      header = Mail::Header.new("To: Mikel\r\nFrom: bob\r\n")
      header['To'].should == "Mikel"
      header['From'].should == "bob"
    end

    it "should return an array of fields if there is more than one match" do
      header = Mail::Header.new
      header.fields = ['From: mikel@me.com', 'X-Mail-SPAM: 15', 'X-Mail-SPAM: 23']
      header['X-Mail-SPAM'].should == ['15', '23']
    end

    it "should return nil if no value in the header" do
      header = Mail::Header.new("To: Mikel\r\nFrom: bob\r\n")
      header['Subject'].should be_nil
    end
    
    it "should add a new field if the field does not exist" do
      header = Mail::Header.new("To: Mikel\r\nFrom: bob\r\n")
      header['Subject'] = "G'Day!"
      header['Subject'].should == "G'Day!"
    end
    
    it "should allow you to pass in an array of raw fields" do
      header = Mail::Header.new
      header.fields = ['From: mikel@me.com', 'To: bob@you.com']
      header['To'].should == 'bob@you.com'
      header['From'].should == 'mikel@me.com'
    end
    
    it "should reset the value of a single-only field if it already exists" do
      header = Mail::Header.new("To: Mikel\r\nFrom: bob\r\n")
      header['To'] = 'George'
      header['To'].should == "George"
    end
    
    it "should allow you to delete a field by setting it to nil" do
      header = Mail::Header.new
      header.fields = ['To: bob@you.com']
      header.fields.length.should == 1
      header['To'] = nil
      header.fields.length.should == 0
    end
    
    it "should delete all matching fields found if there are multiple options" do
      header = Mail::Header.new
      header.fields = ['X-SPAM: 1000', 'X-SPAM: 20']
      header['X-SPAM'] = nil
      header.fields.length.should == 0
    end
    
    it "should return nil if asked for the value of a non existent field" do
      header = Mail::Header.new
      header['Bobs-Field'].should == nil
    end
    
  end

  describe "folding and unfolding" do
    it "should unfold a header" do
      header = Mail::Header.new("To: Mikel,\r\n Lindsaar, Bob")
      header['To'].should == 'Mikel, Lindsaar, Bob'
    end
    
    it "should remove multiple spaces during unfolding a header" do
      header = Mail::Header.new("To: Mikel,\r\n   Lindsaar,     Bob")
      header['To'].should == 'Mikel, Lindsaar, Bob'
    end
    
    it "should handle a crazy long folded header" do
      header_text =<<HERE
Received: from [127.0.220.158] (helo=fg-out-1718.google.com)
	by smtp.totallyrandom.com with esmtp (Exim 4.68)
	(envelope-from <stuff+caf_=support=aaa.somewhere.com@gmail.com>)
	id 1K4JeQ-0005Nd-Ij
	for support@aaa.somewhere.com; Thu, 05 Jun 2008 10:53:29 -0700
HERE
      header = Mail::Header.new(header_text.gsub(/\n/, "\r\n"))
      header['Received'].should == 'from [127.0.220.158] (helo=fg-out-1718.google.com) by smtp.totallyrandom.com with esmtp (Exim 4.68) (envelope-from <stuff+caf_=support=aaa.somewhere.com@gmail.com>) id 1K4JeQ-0005Nd-Ij for support@aaa.somewhere.com; Thu, 05 Jun 2008 10:53:29 -0700'
    end
    
    it "should convert all lonesome LFs to CRLF" do
      header_text =<<HERE
Received: from [127.0.220.158] (helo=fg-out-1718.google.com)
	by smtp.totallyrandom.com with esmtp (Exim 4.68)
	(envelope-from <stuff+caf_=support=aaa.somewhere.com@gmail.com>)
	id 1K4JeQ-0005Nd-Ij
	for support@aaa.somewhere.com; Thu, 05 Jun 2008 10:53:29 -0700
HERE
      header = Mail::Header.new(header_text.gsub(/\n/, "\n"))
      header['Received'].should == 'from [127.0.220.158] (helo=fg-out-1718.google.com) by smtp.totallyrandom.com with esmtp (Exim 4.68) (envelope-from <stuff+caf_=support=aaa.somewhere.com@gmail.com>) id 1K4JeQ-0005Nd-Ij for support@aaa.somewhere.com; Thu, 05 Jun 2008 10:53:29 -0700'
    end
    
    it "should convert all lonesome CRs to CRLF" do
      header_text =<<HERE
Received: from [127.0.220.158] (helo=fg-out-1718.google.com)
	by smtp.totallyrandom.com with esmtp (Exim 4.68)
	(envelope-from <stuff+caf_=support=aaa.somewhere.com@gmail.com>)
	id 1K4JeQ-0005Nd-Ij
	for support@aaa.somewhere.com; Thu, 05 Jun 2008 10:53:29 -0700
HERE
      header = Mail::Header.new(header_text.gsub(/\n/, "\r"))
      header['Received'].should == 'from [127.0.220.158] (helo=fg-out-1718.google.com) by smtp.totallyrandom.com with esmtp (Exim 4.68) (envelope-from <stuff+caf_=support=aaa.somewhere.com@gmail.com>) id 1K4JeQ-0005Nd-Ij for support@aaa.somewhere.com; Thu, 05 Jun 2008 10:53:29 -0700'
    end
    
  end
  
  describe "handling fields with multiple values" do
    it "should know which fields can only appear once" do
      %w[ orig-date from sender reply-to to cc bcc 
          message-id in-reply-to references subject ].each do |field|
        header = Mail::Header.new
        header[field] = "1234"
        header[field] = "5678"
        header[field].should == "5678"
      end
    end
    
    it "should add additional fields that can appear more than once" do
      %w[ comments keywords x-spam].each do |field|
        header = Mail::Header.new
        header[field] = "1234"
        header[field] = "5678"
        header[field].should == ["1234", "5678"]
      end
    end
    
    it "should delete all references to a field" do
      header = Mail::Header.new
      header.fields = ['X-Mail-SPAM: 15', 'X-Mail-SPAM: 20']
      header['X-Mail-SPAM'] = '10000'
      header['X-Mail-SPAM'].should == ['15', '20', '10000']
      header['X-Mail-SPAM'] = nil
      header['X-Mail-SPAM'].should == nil
    end
  end

end