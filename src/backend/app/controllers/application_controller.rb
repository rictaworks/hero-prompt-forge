# frozen_string_literal: true

class ApplicationController < ActionController::API
  # セッションの識別子はクッキーで受け渡します。改ざんを検出するため署名付きで扱います。
  include ActionController::Cookies
end
