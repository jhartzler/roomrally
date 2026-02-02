Rails.application.routes.draw do
  # Static pages
  get "privacy", to: "pages#privacy", as: :privacy
  get "terms", to: "pages#terms", as: :terms

  # Contact form
  resource :contact, only: %i[new create]

  resources :prompt_packs
  get "dashboard", to: "dashboard#index", as: :dashboard
  get "dev/testing", to: "dev_testing#index"
  post "dev/testing/create_test_game", to: "dev_testing#create_test_game"
  get "dev/testing/show_test_game/:id", to: "dev_testing#show_test_game", as: :show_test_game
  get "dev/testing/set_player_session/:id", to: "dev_testing#set_player_session", as: :set_player_session
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"

  resources :rooms, only: %i[create show], param: :code do
    resource :stage, only: :show
    resource :hand, only: :show
    resource :backstage, only: :show
    resources :games, only: :create
    resource :host, only: %i[create update]
  end

  get "/rooms/:code/join", to: "players#new", as: :join_room
  resources :players, only: [ :create, :destroy ]
  resources :responses, only: [ :update ] do
    resources :rejections, only: [ :create, :new ]
  end
  resources :votes, only: [ :create ]

  get "/auth/:provider/callback", to: "sessions#omniauth"
  get "/auth/failure", to: redirect("/")
  delete "/logout", to: "sessions#destroy", as: :logout

  mount ActionCable.server => "/cable"
end
