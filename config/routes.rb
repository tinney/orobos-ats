# frozen_string_literal: true

Rails.application.routes.draw do
  # Health check — available on all domains
  get "up" => "rails/health#show", :as => :rails_health_check

  # Tenant-scoped routes (requests with a valid subdomain)
  constraints Constraints::SubdomainConstraint.new do
    # Authentication — magic link login
    get "login", to: "magic_links#new", as: :login
    post "login", to: "magic_links#create"
    delete "logout", to: "sessions#destroy", as: :logout

    # Admin namespace — team management, settings
    namespace :admin do
      # Dashboard
      root "dashboard#index", as: :dashboard

      resources :users, except: %i[show destroy] do
        member do
          patch :promote
          patch :demote
          patch :deactivate
          patch :reactivate
        end
      end

      resources :roles, only: %i[index show new create edit update] do
        member do
          patch :transition
          post :generate_preview_token
          delete :revoke_preview_token
        end

        resources :interview_phases, only: %i[create update destroy] do
          member do
            patch :move
          end
        end

        resources :custom_questions, only: %i[create update destroy]
        resources :applications, only: %i[index], controller: "applications"
      end

      resources :applications, only: %i[show destroy] do
        member do
          patch :transition
          patch :dismiss_bot_flag
          patch :move_phase
          post :transfer
        end
        resources :offers, only: %i[create edit update]
      end

      # Timezone auto-detection update
      resource :timezone, only: :update

      resources :interviews, only: [] do
        resources :scorecards, only: %i[new create show edit update]
      end

      # Interview management — assigning interviewers to application phases
      resources :applications, only: [] do
        resources :interview_phases, only: [] do
          resource :interview, only: [], controller: "interviews" do
            post :assign, on: :collection
            patch :schedule, on: :member
            patch :complete, on: :member
            patch :cancel, on: :member
            delete :remove_participant, on: :member
          end
        end
      end

      # Global candidates list
      resources :candidates, only: :index

      # My interviews view
      resources :my_interviews, only: :index

      # Unified assignments dashboard
      resources :assignments, only: :index
    end

    # Public careers pages (no auth required)
    resources :careers, only: %i[index show]

    # Public shareable job role URL by slug
    get "jobs/:slug", to: "jobs#show", as: :job

    # Public application form
    get "jobs/:slug/apply", to: "applications#show", as: :job_application
    post "jobs/:slug/apply", to: "applications#create"
    get "jobs/:slug/apply/success", to: "applications#success", as: :job_application_success

    # Role preview — accessible without authentication via preview token
    get "jobs/:id/preview", to: "role_previews#show", as: :role_preview

    # Dashboard and tenant-specific routes will go here
    root "magic_links#new", as: :tenant_root
  end

  # Authentication callback — works on any domain (magic link lands here)
  get "auth/callback", to: "sessions#create", as: :auth_callback
  delete "auth/logout", to: "sessions#destroy", as: :auth_logout

  # Root-domain routes (marketing site / tenant signup, no subdomain)
  get "signup", to: "signups#new", as: :signup
  post "signup", to: "signups#create"
  get "signup/check_subdomain", to: "signups#check_subdomain", as: :check_subdomain
  get "signup/success/:tenant_subdomain", to: "signups#success", as: :signup_success

  root "marketing#index"
end
