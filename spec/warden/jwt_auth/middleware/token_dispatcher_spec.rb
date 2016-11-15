# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

describe Warden::JWTAuth::Middleware::TokenDispatcher do
  include Rack::Test::Methods
  include Warden::Test::Helpers

  include_context 'configuration'

  before { config.response_token_paths = '/sign_in' }

  let(:dummy_app) { ->(_env) { [200, {}, []] } }
  let(:this_app) { described_class.new(dummy_app, config) }
  let(:app) { Warden::Manager.new(this_app) }

  describe '::ENV_KEY' do
    it 'is warden-jwt_auth.token_dispatcher' do
      expect(
        described_class::ENV_KEY
      ).to eq('warden-jwt_auth.token_dispatcher')
    end
  end

  describe '#call(env)' do
    include_context 'revocation'

    before do
      allow(revocation_strategy).to receive(:after_jwt_dispatch)
    end

    it 'adds ENV_KEY key to env' do
      get '/'

      expect(last_request.env[described_class::ENV_KEY]).to eq(true)
    end

    context 'when PATH_INFO matches configured response_token_paths' do
      it 'adds token to the response when user is logged in' do
        login_as Fixtures::User.new

        get '/sign_in'

        expect(last_response.headers['Authorization']).not_to be_nil
      end

      it 'calls revokation strategy hook when user is logged in' do
        login_as Fixtures::User.new

        get '/sign_in'

        expect(config.revocation_strategy).to have_received(
          :after_jwt_dispatch
        )
      end

      it 'adds nothing to the response when user is not logged in' do
        get '/sign_in'

        expect(last_response.headers['Authorization']).to be_nil
      end

      it 'does not call revokation strategy hook when user is not logged in' do
        expect(config.revocation_strategy).not_to have_received(
          :after_jwt_dispatch
        )
      end
    end

    context 'when PATH_INFO does not match configured response_token_paths' do
      before do
        login_as Fixtures::User.new

        get '/another_path'
      end

      it 'adds nothing to the response' do
        expect(last_response.headers['Authorization']).to be_nil
      end

      it 'does not call revokation strategy hook' do
        expect(config.revocation_strategy).not_to have_received(
          :after_jwt_dispatch
        )
      end
    end
  end

  after { Warden.test_reset! }
end
