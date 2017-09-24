# frozen_string_literal: true

require 'spec_helper'

describe RightToKnow do
  let(:fortnight_start) { Date.parse('2017-07-24') }
  let(:fortnight_end)   { Date.parse('2017-08-06') }
  let(:last_fortnight)  { (fortnight_start..fortnight_end).to_a }

  describe 'Website' do
    it 'produces status text for new requests' do
      VCR.use_cassette('righttoknow_variety_sent') do
        text = RightToKnow::Website.new_requests_text(period: last_fortnight)
        expect(text).to eq(':saxophone: 27 new requests were made through Right To Know last fortnight.')
      end
    end

    it 'produces status text for annotations' do
      VCR.use_cassette('righttoknow_variety_comment') do
        text = RightToKnow::Website.annotations_text(period: last_fortnight)
        expect(text).to eq(':heartbeat: Our contributors helped people with 14 annotations.')
      end
    end

    it 'produces status text for successful requests' do
      VCR.use_cassette('righttoknow_status_successful') do
        text = RightToKnow::Website.success_text(period: last_fortnight)
        expect(text).to eq(':trophy: 7 requests were marked successful!')
      end
    end
  end

  describe RightToKnow::Runner do
    it_behaves_like 'a runner'
  end
end
