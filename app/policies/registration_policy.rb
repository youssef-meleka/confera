class RegistrationPolicy < ApplicationPolicy
  def index?  = true
  def create? = true

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.where(user_id: user.id)
  end
end
