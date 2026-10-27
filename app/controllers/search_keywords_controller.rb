# frozen_string_literal: true

class SearchKeywordsController < ApplicationController
  def index
    render locals: { search_keywords: SearchKeyword.order(:phrase) }
  end

  def show
    render locals: { search_keyword: }
  end

  def new
    render locals: { search_keyword: }
  end

  def create
    if search_keyword.save
      redirect_to search_keyword, notice: "Keyword added."
    else
      render :new, status: :unprocessable_entity, locals: { search_keyword: }
    end
  end

  def edit
    render locals: { search_keyword: }
  end

  def update
    if search_keyword.update search_keyword_params
      redirect_to search_keyword, notice: "Keyword updated."
    else
      render :edit, status: :unprocessable_entity, locals: { search_keyword: }
    end
  end

  private

  def search_keyword
    @search_keyword ||= if params[:id]
      SearchKeyword.find params[:id]
    elsif params[:search_keyword]
      SearchKeyword.new search_keyword_params
    else
      SearchKeyword.new
    end
  end

  def search_keyword_params
    params.expect search_keyword: [ :phrase, :active, :exclude_phrase ]
  end
end
