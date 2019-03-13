class Credential < ApplicationRecord
  Type = GraphQL::ObjectType.define do
    name "Credential"
    field :isLoggedIn, !types.Boolean, property: :logged_in?
    field :isAdmin, !types.Boolean, property: :admin?
  end

  before_create :set_expires_at

  def admin?
    return true if Rails.env.development?

    if @admin.nil?
      client.authenticated_admin?
    else
      @admin
    end
  rescue Panoptes::Client::NotLoggedIn, Panoptes::Client::AuthenticationExpired
    false
  end

  def authenticate!
    client.authenticated?
  end

  def display_name
    client.authenticated_user_display_name
  end

  def expired?
    client.token_expiry < Time.now.utc
  end

  def logged_in?
    return true if Rails.env.development?

    if @logged_in.nil?
      client.authenticated?
    else
      @logged_in
    end
  rescue Panoptes::Client::NotLoggedIn, Panoptes::Client::AuthenticationExpired
    false
  end

  def login
    if @login.nil?
      client.authenticated_user_login
    else
      @login
    end
  end

  def user_id
    if @user_id.nil?
      client.authenticated_user_id
    else
      @user_id
    end
  end

  def fetch_accessible_projects
    client.panoptes.paginate("/projects", current_user_roles: ['owner', 'collaborator'])
  end

  def accessible_project?(id)
    admin? || project_ids.map(&:to_s).include?(id.to_s)
  end

  def accessible_workflow?(id)
    workflow_hash = client.workflow(id.to_s)
    project_id = workflow_hash&.dig("links", "project")

    if accessible_project? project_id
      workflow_hash&.merge!("project_id" => project_id)
    else
      nil
    end
  rescue Panoptes::Client::ResourceNotFound
    nil
  end

  private

  def client
    @client ||= Panoptes::Client.new(env: panoptes_client_env, auth: {token: token})
  end

  def panoptes_client_env
    case Rails.env.to_s
    when "production"
      "production"
    when "test"
      "test"
    else
      "staging"
    end
  end

  def set_expires_at
    self.expires_at ||= Time.at(client.token_expiry)
  end
end
