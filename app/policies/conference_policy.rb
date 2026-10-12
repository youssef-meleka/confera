class ConferencePolicy < ApplicationPolicy
  def index?   = true
  def show?    = record.published? || owner?
  def create?  = true
  def update?  = owner?
  def destroy? = owner?
  def publish? = owner?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(published: true).or(scope.where(organizer_id: user.id))
    end
  end

  private

  def owner? = record.organizer_id == user.id
end
