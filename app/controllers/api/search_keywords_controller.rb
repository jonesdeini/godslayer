# frozen_string_literal: true

class Api::SearchKeywordsController < Api::BaseController
  def index
    render :index, locals: { keywords: SearchKeyword.where(active: true) }
  end
end
