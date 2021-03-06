require 'spec_helper'

class Person < ActiveRecord::Base
  has_many :androids, :foreign_key => :owner_id, :dependent => :destroy
end

class Android < ActiveRecord::Base
  validates_uniqueness_of :name
  is_paranoid
  named_scope :ordered, :order => 'name DESC'
  named_scope :r2d2, :conditions => { :name => 'R2D2' }
  named_scope :c3p0, :conditions => { :name => 'C3P0' }
end

describe Android do
  before(:each) do
    Android.connection.execute 'DELETE FROM androids'
    Person.connection.execute 'DELETE FROM people'

    @luke = Person.create(:name => 'Luke Skywalker')
    @r2d2 = Android.create(:name => 'R2D2', :owner_id => @luke.id)
    @c3p0 = Android.create(:name => 'C3P0', :owner_id => @luke.id)
  end

  it "should delete normally" do
    Android.count_with_destroyed.should == 2
    Android.delete_all
    Android.count_with_destroyed.should == 0
  end

  it "should handle Model.destroy_all properly" do
    lambda{
      Android.destroy_all("owner_id = #{@luke.id}")
    }.should change(Android, :count).from(2).to(0)
    Android.count_with_destroyed.should == 2
  end

  it "should handle Model.destroy(id) properly" do
    lambda{
      Android.destroy(@r2d2.id)
    }.should change(Android, :count).by(-1)

    Android.count_with_destroyed.should == 2
  end

  it "should be not show up in the relationship to the owner once deleted" do
    @luke.androids.size.should == 2
    @r2d2.destroy
    @luke.androids.size.should == 1
    Android.count.should == 1
    Android.first(:conditions => {:name => 'R2D2'}).should be_blank
  end

  it "should be able to find deleted items via find_with_destroyed" do
    @r2d2.destroy
    Android.find(:first, :conditions => {:name => 'R2D2'}).should be_blank
    Android.find_with_destroyed(:first, :conditions => {:name => 'R2D2'}).should_not be_blank
  end

  it "should have a proper count inclusively and exclusively of deleted items" do
    @r2d2.destroy
    @c3p0.destroy
    Android.count.should == 0
    Android.count_with_destroyed.should == 2
  end

  it "should mark deleted on dependent destroys" do
    lambda{
      @luke.destroy
    }.should change(Android, :count).by(-2)
    Android.count_with_destroyed.should == 2
  end

  it "should allow restoring" do
    @r2d2.destroy
    lambda{
      @r2d2.restore
    }.should change(Android, :count).by(1)
  end

  # Note:  this isn't necessarily ideal, this just serves to demostrate
  # how it currently works
  it "should not ignore deleted items in validation checks" do
    @r2d2.destroy
    lambda{
      Android.create!(:name => 'R2D2')
    }.should raise_error(ActiveRecord::RecordInvalid)
  end
  
  it "should find only destroyed videos" do
    @r2d2.destroy
    Android.find_only_destroyed(:all).should == [@r2d2]
  end

  it "should honor named scopes" do
    @r2d2.destroy
    @c3p0.destroy
    Android.r2d2.find_only_destroyed(:all).should == [@r2d2]
    Android.c3p0.ordered.find_only_destroyed(:all).should == [@c3p0]
    Android.ordered.find_only_destroyed(:all).should == [@r2d2,@c3p0]
    Android.r2d2.c3p0.find_only_destroyed(:all).should == []
    Android.find_only_destroyed(:all).should == [@r2d2,@c3p0]
  end
end
