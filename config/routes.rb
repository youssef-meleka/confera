Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :users, only: [:create]

      post   "sessions",         to: "sessions#create"
      delete "sessions/current", to: "sessions#destroy"

      resources :conferences do
        post :publish, on: :member
        resources :talks, only: [:index]
      end
      resources :registrations, only: [:index, :create]
    end
  end

  # Keep engine routes (Active Storage, Action Mailbox, ...) reachable
  match "*unmatched", to: "application#route_not_found", via: :all,
        constraints: ->(req) { !req.path.start_with?("/rails/") }
end
