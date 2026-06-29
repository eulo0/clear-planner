Rails.application.routes.draw do
  resources :projects do
    collection do
      delete :destroy_all
    end
    get :agenda, on: :member
    get :chat, on: :member
    get :join, on: :collection
    resources :project_invitations, only: %i[new create] do
      get :members, on: :collection
    end
    resources :project_messages, only: [ :create ]
    resources :project_memberships, only: %i[update destroy]
  end
  get "project_invitations/accept", to: "project_invitations#accept", as: :accept_project_invitation
  devise_for :users, controllers: {
    registrations: "users/registrations",
    confirmations: "users/confirmations",
    sessions: "users/auth",
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  resource :profile, only: [ :show, :edit, :update ] do
    patch :update_username
    get :edit_password
    patch :update_password
    get :edit_avatar
    patch :update_avatar
    get :delete_account
    delete :destroy_account
  end

  # Theme
  resource :theme, only: [ :new, :update, :create, :destroy ] do
    get :new, on: :collection
    get :edit, on: :member
    delete :reset, on: :member
    delete :destroy, on: :member
  end

  resource :calendar_export, only: [ :show ]
  resource :calendar_import, only: [ :create ]

  resources :events do
    collection do
      delete :destroy_all
    end
    member do
      post :convert
      patch :reschedule
    end
  end

  resources :work_shifts do
    collection do
      delete :destroy_all
    end
    member do
      post :convert
    end
  end

  get "auto_schedule/preview", to: "auto_schedule#preview", as: :auto_schedule_preview

  scope :university_calendar do
    get  "preview",     to: "university_calendar#preview",     as: :university_calendar_preview
    get  "pdf_preview", to: "university_calendar#pdf_preview_page", as: :university_calendar_pdf_preview_page
    post "pdf_preview", to: "university_calendar#pdf_preview", as: :university_calendar_pdf_preview
    post "import",      to: "university_calendar#import",      as: :university_calendar_import
  end
  resources :courses do
    collection do
      delete :destroy_all
    end
    member do
      patch :update_grade_weights
      patch :update_grade_calculation
      get   :grades
      post  :convert
      patch :reschedule
    end
    resources :course_items, only: %i[index create show edit update destroy] do
      member do
        patch :reschedule
      end
    end
  end
  resources :agenda

  # Canvas sync is managed inline from the profile drawer; these are the backing
  # action endpoints (no standalone show/new page).
  resource :canvas_sync, only: %i[create update destroy],
           controller: "canvas_subscriptions", path: "syncs" do
    post :refresh, on: :collection
  end

  resources :syllabuses do
    member do
      post :create_course
      get  :status
      get  :course_preview
      get  :course_preview_frame
      post :confirm_course
      get  :course_items_preview
      post :confirm_course_items
    end
  end

  # First-login syllabus onboarding (full-screen flow). All actions are scoped
  # to current_user; no record IDs appear in these paths.
  get  "onboarding",         to: "onboarding#show",    as: :onboarding
  post "onboarding/files",   to: "onboarding#create",  as: :onboarding_files
  get  "onboarding/status",  to: "onboarding#status",  as: :onboarding_status
  get  "onboarding/review",  to: "onboarding#review",  as: :onboarding_review
  post "onboarding/confirm", to: "onboarding#confirm", as: :onboarding_confirm
  get  "onboarding/done",    to: "onboarding#done",    as: :onboarding_done
  post "onboarding/skip",    to: "onboarding#skip",    as: :onboarding_skip

  resources :ai_chat, only: [ :create ] do
    collection do
      get :usage
      get :panel
    end
  end

  resources :notifications, only: [ :index, :destroy ] do
    member do
      patch :mark_read
    end
    collection do
      delete :destroy_all
    end
  end

  # Admin-only pages (guarded in controllers via current_user.admin?)
  namespace :admin do
    resources :users, only: [ :index, :destroy ] do
      member do
        get  :edit_password
        patch :update_password
      end
    end
  end

  if Rails.env.development?
    begin
      require "letter_opener_web"
      mount LetterOpenerWeb::Engine, at: "/letter_opener"
    rescue LoadError
    end
  end

  authenticated :user do
    root "analytics#show", as: :authenticated_root
  end

  unauthenticated do
    root "home#index"
  end

  # The calendar (DashboardController#show) now lives at /calendar; the `dashboard`
  # helper name is kept stable so existing dashboard_path references resolve here.
  get "/calendar",       to: "dashboard#show", as: :dashboard
  get "calendar/agenda", to: "dashboard#agenda", as: :dashboard_agenda

  post   "calendar/draft",         to: "draft#enter",   as: :enter_draft
  post   "calendar/draft/create",  to: "draft#create",  as: :create_draft
  get    "calendar/draft/changes", to: "draft#changes", as: :draft_changes
  patch  "calendar/draft/restore", to: "draft#restore", as: :draft_restore
  patch  "calendar/draft/apply",   to: "draft#apply",   as: :apply_draft
  delete "calendar/draft",         to: "draft#discard", as: :discard_draft
  patch  "calendar/draft/exit",    to: "draft#exit",    as: :exit_draft
  patch  "calendar/draft/:id/name", to: "draft#rename",  as: :rename_draft
  delete "calendar/draft/:id",     to: "draft#destroy", as: :delete_draft


  get "projects/join", to: "projects#join", as: :join_project
  get "/ui",             to: "ui#show"
  # The analytics page is now the user-facing "Dashboard", served at /dashboard.
  # Helper names (analytics / analytics_compare) are kept stable.
  get "/dashboard",         to: "analytics#show",    as: "analytics"
  get "/dashboard/compare", to: "analytics#compare", as: "analytics_compare"
  resources :tasks, only: %i[index new create show edit update destroy] do
    member do
      patch :toggle
    end
  end
  get "/schedule",       to: "schedule#week"
  get "/schedule/week",  to: "schedule#week"

  get "up" => "rails/health#show", as: :rails_health_check
end
