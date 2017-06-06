# encoding: utf-8
# frozen_string_literal: true
require 'spec_helper'

describe "exim delivery agent" do
  
  before do
    Mail.defaults do
      delivery_method :exim
    end
  end

  it "should send an email using exim" do
    mail = Mail.new do
      from    'roger@test.lindsaar.net'
      to      'marcel@test.lindsaar.net, bob@test.lindsaar.net'
      subject 'invalid RFC2822'
    end

    expect(Mail::Sendmail).to receive(:call).with('/usr/sbin/exim', '-i -t -f "roger@test.lindsaar.net" --', nil, mail.encoded)

    mail.deliver!
  end

  describe "return path" do

    it "should send an email with a return-path using exim" do
      mail = Mail.new do
        to "to@test.lindsaar.net"
        from "from@test.lindsaar.net"
        sender "sender@test.lindsaar.net"
        subject "Can't set the return-path"
        return_path "return@test.lindsaar.net"
        message_id "<1234@test.lindsaar.net>"
        body "body"
      end

      expect(Mail::Sendmail).to receive(:call).with('/usr/sbin/exim', '-i -t -f "return@test.lindsaar.net" --', nil, mail.encoded)

      mail.deliver
    end

    it "should use the sender address is no return path is specified" do
      mail = Mail.new do
        to "to@test.lindsaar.net"
        from "from@test.lindsaar.net"
        sender "sender@test.lindsaar.net"
        subject "Can't set the return-path"
        message_id "<1234@test.lindsaar.net>"
        body "body"
      end

      expect(Mail::Sendmail).to receive(:call).with('/usr/sbin/exim', '-i -t -f "sender@test.lindsaar.net" --', nil, mail.encoded)

      mail.deliver
    end

    it "should use the from address is no return path or sender are specified" do
      mail = Mail.new do
        to "to@test.lindsaar.net"
        from "from@test.lindsaar.net"
        subject "Can't set the return-path"
        message_id "<1234@test.lindsaar.net>"
        body "body"
      end

      expect(Mail::Sendmail).to receive(:call).with('/usr/sbin/exim', '-i -t -f "from@test.lindsaar.net" --', nil, mail.encoded)

      mail.deliver
    end

    it "should escape the return path address" do
      mail = Mail.new do
        to 'to@test.lindsaar.net'
        from '"from+suffix test"@test.lindsaar.net'
        subject 'Can\'t set the return-path'
        message_id '<1234@test.lindsaar.net>'
        body 'body'
      end

      expect(Mail::Sendmail).to receive(:call).with('/usr/sbin/exim', '-i -t -f "\"from+suffix test\"@test.lindsaar.net" --', nil, mail.encoded)

      mail.deliver
    end

    it "should quote the destinations to ensure leading -hyphen doesn't confuse exim" do
      mail = Mail.new do
        to '-hyphen@test.lindsaar.net'
        from 'from@test.lindsaar.net'
      end

      expect(Mail::Sendmail).to receive(:call).with('/usr/sbin/exim', '-i -t -f "from@test.lindsaar.net" --', nil, mail.encoded)

      mail.deliver
    end
  end

  it "should still send an email if the settings have been set to nil" do
    Mail.defaults do
      delivery_method :exim, :arguments => nil
    end
    
    mail = Mail.new do
      from    'from@test.lindsaar.net'
      to      'marcel@test.lindsaar.net, bob@test.lindsaar.net'
      subject 'invalid RFC2822'
    end
    
    expect(Mail::Sendmail).to receive(:call).with('/usr/sbin/exim', ' -f "from@test.lindsaar.net" --', nil, mail.encoded)

    mail.deliver!
  end

  it "should escape evil haxxor attemptes" do
    mail = Mail.new do
      from    '"foo\";touch /tmp/PWNED;\""@blah.com'
      to      'marcel@test.lindsaar.net'
      subject 'invalid RFC2822'
    end

    expect(Mail::Sendmail).to receive(:call).with(
      '/usr/sbin/exim',
      "-i -t -f \"\\\"foo\\\\\\\"\\;touch /tmp/PWNED\\;\\\\\\\"\\\"@blah.com\" --",
      nil,
      mail.encoded)

    mail.deliver!
  end

  it "should not raise errors if no sender is defined" do
    mail = Mail.new do
      to "to@somemail.com"
      subject "Email with no sender"
      body "body"
    end

    expect(mail.smtp_envelope_from).to be_nil

    expect do
      mail.deliver
    end.to raise_error('SMTP From address may not be blank: nil')
  end

  it "should raise an error if no recipient if defined" do
    mail = Mail.new do
      from "from@somemail.com"
      subject "Email with no recipient"
      body "body"
    end

    expect(mail.smtp_envelope_to).to eq([])

    expect do
      mail.deliver
    end.to raise_error('SMTP To address may not be blank: []')
  end
end
