# frozen_string_literal: true

#
#    Copyright 2016-2018, Optimizely and contributors
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
require 'spec_helper'
require 'webmock'
require 'optimizely/error_handler'
require 'optimizely/event_builder'
require 'optimizely/logger'

describe Optimizely::EventBuilder do
  config = nil
  before(:context) do
    @config_body = OptimizelySpec::VALID_CONFIG_BODY
    @config_body_json = OptimizelySpec::VALID_CONFIG_BODY_JSON
    @error_handler = Optimizely::NoOpErrorHandler.new
    @logger = Optimizely::SimpleLogger.new
  end

  before(:example) do
    config = Optimizely::ProjectConfig.new(@config_body_json, @logger, @error_handler)
    @event_builder = Optimizely::EventBuilder.new(config, @logger)

    time_now = Time.now
    allow(Time).to receive(:now).and_return(time_now)
    allow(SecureRandom).to receive(:uuid).and_return('a68cf1ad-0393-4e18-af87-efe8f01a7c9c')

    @expected_endpoint = 'https://logx.optimizely.com/v1/events'
    @expected_impression_params = {
      account_id: '12001',
      project_id: '111001',
      visitors: [{
        attributes: [{
          entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          type: 'custom',
          value: true
        }],
        visitor_id: 'test_user',
        snapshots: [{
          decisions: [{
            campaign_id: '1',
            experiment_id: '111127',
            variation_id: '111128'
          }],
          events: [{
            entity_id: '1',
            timestamp: (time_now.to_f * 1000).to_i,
            uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c',
            key: 'campaign_activated'
          }]
        }]
      }],
      anonymize_ip: false,
      revision: '42',
      client_name: Optimizely::CLIENT_ENGINE,
      client_version: Optimizely::VERSION
    }
    @expected_conversion_params = {
      account_id: '12001',
      project_id: '111001',
      visitors: [{
        attributes: [{
          entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
          type: 'custom',
          value: true
        }],
        visitor_id: 'test_user',
        snapshots: [{
          decisions: [{
            campaign_id: '1',
            experiment_id: '111127',
            variation_id: '111128'
          }],
          events: [{
            entity_id: '111095',
            timestamp: (time_now.to_f * 1000).to_i,
            uuid: 'a68cf1ad-0393-4e18-af87-efe8f01a7c9c',
            key: 'test_event'
          }]
        }]
      }],
      anonymize_ip: false,
      revision: '42',
      client_name: Optimizely::CLIENT_ENGINE,
      client_version: Optimizely::VERSION
    }
  end

  it 'should create valid Event when create_impression_event is called without attributes' do
    experiment = config.get_experiment_from_key('test_experiment')
    impression_event = @event_builder.create_impression_event(experiment, '111128', 'test_user', nil)
    expect(impression_event.params).to eq(@expected_impression_params)
    expect(impression_event.url).to eq(@expected_endpoint)
    expect(impression_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_impression_event is called with attributes as a string value' do
    @expected_impression_params[:visitors][0][:attributes].unshift(
      entity_id: '111094',
      key: 'browser_type',
      type: 'custom',
      value: 'firefox'
    )

    experiment = config.get_experiment_from_key('test_experiment')
    impression_event = @event_builder.create_impression_event(experiment, '111128', 'test_user',
                                                              'browser_type' => 'firefox')
    expect(impression_event.params).to eq(@expected_impression_params)
    expect(impression_event.url).to eq(@expected_endpoint)
    expect(impression_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_impression_event is called with attributes as a false value' do
    @expected_impression_params[:visitors][0][:attributes].unshift(
      entity_id: '111094',
      key: 'browser_type',
      type: 'custom',
      value: false
    )

    experiment = config.get_experiment_from_key('test_experiment')
    impression_event = @event_builder.create_impression_event(experiment, '111128', 'test_user',
                                                              'browser_type' => false)
    expect(impression_event.params).to eq(@expected_impression_params)
    expect(impression_event.url).to eq(@expected_endpoint)
    expect(impression_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_impression_event is called with attributes as a zero value' do
    @expected_impression_params[:visitors][0][:attributes].unshift(
      entity_id: '111094',
      key: 'browser_type',
      type: 'custom',
      value: 0
    )

    experiment = config.get_experiment_from_key('test_experiment')
    impression_event = @event_builder.create_impression_event(experiment, '111128', 'test_user', 'browser_type' => 0)
    expect(impression_event.params).to eq(@expected_impression_params)
    expect(impression_event.url).to eq(@expected_endpoint)
    expect(impression_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_impression_event is called with attributes is not in the datafile' do
    experiment = config.get_experiment_from_key('test_experiment')
    impression_event = @event_builder.create_impression_event(experiment, '111128', 'test_user',
                                                              invalid_attribute: 'sorry_not_sorry')
    expect(impression_event.params).to eq(@expected_impression_params)
    expect(impression_event.url).to eq(@expected_endpoint)
    expect(impression_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called' do
    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, nil, '111127' => '111128')
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_endpoint)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with attributes' do
    @expected_conversion_params[:visitors][0][:attributes].unshift(
      entity_id: '111094',
      key: 'browser_type',
      type: 'custom',
      value: 'firefox'
    )

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', {'browser_type' => 'firefox'},
                                                              nil, '111127' => '111128')
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_endpoint)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with revenue event tag' do
    event_tags = {'revenue' => 4200}

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0].merge!(revenue: 4200,
                                                                                tags: event_tags)

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, event_tags,
                                                              '111127' => '111128')
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_endpoint)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with valid string revenue event tag' do
    event_tags = {'revenue' => '4200'}

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0].merge!(revenue: 4200,
                                                                                tags: event_tags)

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, event_tags,
                                                              '111127' => '111128')
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_endpoint)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with invalid revenue event tag' do
    event_tags = {'revenue' => 'invalid revenue'}

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0][:tags] = event_tags

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, event_tags,
                                                              '111127' => '111128')
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_endpoint)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with non-revenue event tag' do
    event_tags = {'non-revenue' => 4200}

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0][:tags] = event_tags

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, event_tags,
                                                              '111127' => '111128')
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_endpoint)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with revenue and non-revenue event tags' do
    event_tags = {
      'revenue' => 4200,
      'non-revenue' => 4200
    }

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0].merge!(revenue: 4200,
                                                                                tags: event_tags)

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, event_tags,
                                                              '111127' => '111128')
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_endpoint)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with boolean event tag' do
    event_tags = {
      'boolean_tag' => false,
      'nil_tag' => nil
    }

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0][:tags] = event_tags

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, event_tags,
                                                              '111127' => '111128')
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_endpoint)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with string event tag' do
    event_tags = {
      'string_tag' => 'iamstring'
    }

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0][:tags] = event_tags

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, event_tags,
                                                              '111127' => '111128')
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_endpoint)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with integer event tag' do
    event_tags = {
      'integer_tag' => 42
    }

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0][:tags] = event_tags

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, event_tags,
                                                              '111127' => '111128')
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_endpoint)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with float event tag' do
    event_tags = {
      'float_tag' => 42.01
    }

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0][:tags] = event_tags

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, event_tags,
                                                              '111127' => '111128')
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_endpoint)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with value event tag' do
    event_tags = {
      'value' => '13.37'
    }

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0].merge!(value: 13.37,
                                                                                tags: event_tags)

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, event_tags,
                                                              '111127' => '111128')
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_endpoint)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with invalid value event tag' do
    event_tags = {
      'value' => 'invalid value'
    }

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0][:tags] = event_tags

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, event_tags,
                                                              '111127' => '111128')
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_endpoint)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create a valid Event when create_conversion_event is called with attributes and event tags for revenue, '\
     'value and other tag' do
    event_tags = {
      'revenue' => 4200,
      'value' => 13.37,
      'other' => 'some value'
    }

    @expected_conversion_params[:visitors][0][:snapshots][0][:events][0].merge!(revenue: 4200,
                                                                                value: 13.37,
                                                                                tags: event_tags)

    @expected_conversion_params[:visitors][0][:attributes].unshift(
      entity_id: '111094',
      key: 'browser_type',
      type: 'custom',
      value: 'firefox'
    )

    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', {'browser_type' => 'firefox'},
                                                              event_tags, '111127' => '111128')
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_endpoint)
    expect(conversion_event.http_verb).to eq(:post)
  end

  # Create impression event with bucketing ID
  it 'should create valid Event when create_impression_event is called with Bucketing ID attribute' do
    @expected_impression_params[:visitors][0][:attributes].unshift(
      {
        entity_id: '111094',
        key: 'browser_type',
        type: 'custom',
        value: 'firefox'
      },
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'],
      type: 'custom',
      value: 'variation'
    )

    user_attributes = {
      'browser_type' => 'firefox',
      '$opt_bucketing_id' => 'variation'
    }
    experiment = config.get_experiment_from_key('test_experiment')
    impression_event = @event_builder.create_impression_event(experiment, '111128', 'test_user', user_attributes)
    expect(impression_event.params).to eq(@expected_impression_params)
    expect(impression_event.url).to eq(@expected_endpoint)
    expect(impression_event.http_verb).to eq(:post)
  end

  it 'should create valid Event with user agent when bot_filtering is enabled' do
    # Test that create_impression_event creates Event object
    # with right params when user agent attribute is provided and
    # bot filtering is enabled

    @expected_impression_params[:visitors][0][:attributes] = [{
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      type: 'custom',
      value: true
    }]

    @expected_impression_params[:visitors][0][:attributes].unshift(
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['USER_AGENT'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['USER_AGENT'],
      type: 'custom',
      value: 'test'
    )
    user_attributes = {
      '$opt_user_agent' => 'test'
    }
    experiment = config.get_experiment_from_key('test_experiment')
    expect(@event_builder.send(:bot_filtering)).to eq(true)
    impression_event = @event_builder.create_impression_event(experiment, '111128', 'test_user', user_attributes)
    expect(impression_event.params).to eq(@expected_impression_params)
    expect(impression_event.url).to eq(@expected_endpoint)
    expect(impression_event.http_verb).to eq(:post)
  end

  it 'should create valid Event with user agent when bot_filtering is disabled' do
    # Test that create_impression_event creates Event object
    # with right params when user agent attribute is provided and
    # bot filtering is disabled

    @expected_impression_params[:visitors][0][:attributes] = [{
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      type: 'custom',
      value: false
    }]
    @expected_impression_params[:visitors][0][:attributes].unshift(
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['USER_AGENT'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['USER_AGENT'],
      type: 'custom',
      value: 'test'
    )

    user_attributes = {
      '$opt_user_agent' => 'test'
    }
    experiment = config.get_experiment_from_key('test_experiment')
    allow(@event_builder).to receive(:bot_filtering).and_return(false)
    impression_event = @event_builder.create_impression_event(experiment, '111128', 'test_user', user_attributes)
    expect(impression_event.params).to eq(@expected_impression_params)
    expect(impression_event.url).to eq(@expected_endpoint)
    expect(impression_event.http_verb).to eq(:post)
  end

  # Create conversion event with bucketing ID
  it 'should create valid Event when create_conversion_event is called with Bucketing ID attribute' do
    @expected_conversion_params[:visitors][0][:attributes].unshift(
      {
        entity_id: '111094',
        key: 'browser_type',
        type: 'custom',
        value: 'firefox'
      },
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BUCKETING_ID'],
      type: 'custom',
      value: 'variation'
    )

    user_attributes = {
      'browser_type' => 'firefox',
      '$opt_bucketing_id' => 'variation'
    }
    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', user_attributes, nil,
                                                              '111127' => '111128')
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_endpoint)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create valid Event with user agent when bot_filtering is enabled' do
    # Test that create_conversion_event creates Event object
    # with right params when user agent attribute is provided and
    # bot filtering is enabled

    @expected_conversion_params[:visitors][0][:attributes].unshift(
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['USER_AGENT'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['USER_AGENT'],
      type: 'custom',
      value: 'test'
    )

    user_attributes = {
      '$opt_user_agent' => 'test'
    }
    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', user_attributes, nil,
                                                              '111127' => '111128')
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_endpoint)
    expect(conversion_event.http_verb).to eq(:post)
  end

  it 'should create valid Event with user agent when bot_filtering is disabled' do
    # Test that create_conversion_event creates Event object
    # with right params when user agent attribute is provided and
    # bot filtering is disabled
    @expected_conversion_params[:visitors][0][:attributes] = [{
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['BOT_FILTERING'],
      type: 'custom',
      value: false
    }]

    @expected_conversion_params[:visitors][0][:attributes].unshift(
      entity_id: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['USER_AGENT'],
      key: Optimizely::Helpers::Constants::CONTROL_ATTRIBUTES['USER_AGENT'],
      type: 'custom',
      value: 'test'
    )

    user_attributes = {
      '$opt_user_agent' => 'test'
    }
    allow(@event_builder).to receive(:bot_filtering).and_return(false)
    conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', user_attributes, nil,
                                                              '111127' => '111128')
    expect(conversion_event.params).to eq(@expected_conversion_params)
    expect(conversion_event.url).to eq(@expected_endpoint)
    expect(conversion_event.http_verb).to eq(:post)
  end

  describe 'multiple_experiments_event' do
    it 'should create_conversion_event when Event is used in multiple experiments' do
      @expected_conversion_params[:visitors][0][:snapshots][0][:decisions] = [{
        campaign_id: '1',
        experiment_id: '111127',
        variation_id: '111128'
      }, {
        campaign_id: '4',
        experiment_id: '122230',
        variation_id: '122231'
      }]

      conversion_event = @event_builder.create_conversion_event('test_event', 'test_user', nil, nil, '111127' => '111128', '122230' => '122231')
      expect(conversion_event.params).to eq(@expected_conversion_params)
      expect(conversion_event.url).to eq(@expected_endpoint)
      expect(conversion_event.http_verb).to eq(:post)
    end
  end
end