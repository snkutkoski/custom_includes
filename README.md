# CustomIncludes

CustomIncludes provides functionality similar to [includes](http://api.rubyonrails.org/classes/ActiveRecord/QueryMethods.html#method-i-includes) for ActiveRecord objects that are associated to potentially non-ActiveRecord objects. It accomplishes this by matching up a column on the database table with a field in the associated object. Using CustomIncludes requires defining two "finder" methods per custom association that retrieve associated objects, as documented in the Usage sections of this README.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'custom_includes', git: 'git@bitbucket.org:Steven_Kutkoski/custom_include.git', branch: :master
```

And then execute:

    $ bundle install


## Basic Usage

CustomIncludes may be useful in a variety of situations, such as when the associated object does not exist in your application's database but is retrievable through HTTP requests. For example, the following would produce multiple HTTP requests.

```ruby
class Positions < ActiveRecord::Base
  def facility
    find_facility_via_http(facility_id)
  end
end

positions = Positions.where('created_at > ?', Time.now - 1.day)
positions.each do |p|
  puts p.facility  
end
```

But this would only create one request.

```ruby
class Positions < ActiveRecord::Base
  custom_belongs_to :facility, :facility_id, :id

  def find_facility
    find_facility_via_http(facility_id)
  end
  
  def facility_custom_includes(facility_ids)
    find_all_facilities_via_http(facility_ids)
  end
end

positions = Positions.custom_includes(:facility).where('created_at > ?', Time.now - 1.day)
positions.each do |p|
  puts p.facility  
end
```

Obviously, this would require the "find_all_facilities_via_http" method to only perform one request. The advantage of CustomIncludes is the ability to chain it with normal ActiveRecord query methods and assign the facilities to the correct position in the resulting ActiveRecord::Relation.

## Detailed Usage Description

* Include the module.
```ruby
    include CustomIncludes
```
* Configure the association. CustomIncludes needs to know what to call this association, what column to use, and what attribute to compare it to in the associated object.
```ruby
    belongs_to :associated, :column_name, :associated_id
```
* Provide a finder method for an individual record. This method must be named "find_associated" and not just "associated." This is because CustomIncludes generates the "associated" method so that when it is called it checks for an included association before performing the find.
```
    def find_associated
      # Implement a method that returns the associated object here. Its associated_id should match the column_name
    end
```
* Provide a finder method for including associations named "associated_custom_includes". This method should return all the associated objects that match given ids. This method is called when a query is executed that contains a "custom_includes" as part of its query chain.
```ruby
    def associated_custom_includes(associated_ids)
      # Implement a method that returns the associated objects with the given associated_ids as an Array.
    end
```
* Use the custom_includes method. When this is added to an ActiveRecord query chain, it tells CustomIncludes to perform the "associated_custom_includes" method once the rest of the query is completed. It passes all the values in the results' "column_name" values to this method. Then, it assigns the resulting associated objects to the correct ActiveRecord object by comparing it to the "column_name" values. Any future calls to "associated" will return this included object rather than performing find_associated.
```ruby
    # Runs associated_custom_includes
    models = MyModel.where(something).includes(something).custom_includes(:associated).where(something_else)
    
    # Returns the already included association
    models[0].associated
```

### Options
* raise_on_not_found
    * Defaults to false
    * If true, raises an Error when the query returns a model that does not have a matching association returned from associated_custom_includes.
    * If false, sets the associated object to nil when the query returns a model that does not have a matching association returned from associated_custom_includes.