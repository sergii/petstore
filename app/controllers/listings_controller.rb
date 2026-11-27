class ListingsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  before_action :set_owned_listing, only: %i[edit update destroy]

  def index
    @listings = Listing.recent
    @listings = @listings.where(category: params[:category]) if Listing::CATEGORIES.include?(params[:category])
    if params[:q].present?
      query = "%#{Listing.sanitize_sql_like(params[:q].to_s.strip)}%"
      @listings = @listings.where("title LIKE :query OR description LIKE :query", query: query)
    end
  end

  def show
    @listing = Listing.find(params[:id])
  end

  def mine
    @listings = Current.user.listings.recent
  end

  def new
    @listing = Current.user.listings.build
  end

  def create
    @listing = Current.user.listings.build(listing_params)
    if @listing.save
      redirect_to @listing, notice: "Listing published."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @listing.update(listing_params)
      redirect_to @listing, notice: "Listing updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @listing.destroy!
    redirect_to my_listings_path, notice: "Listing removed.", status: :see_other
  end

  private

  def set_owned_listing
    @listing = Current.user.listings.find(params[:id])
  end

  def listing_params
    params.expect(listing: %i[title description category condition price])
  end
end
