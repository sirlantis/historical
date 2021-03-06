# Historical: Versioning and Auditing

There are several plugins available for versioning (e.g. `acts_as_versioned`, `simply_versioned`, `vestal_versions`). Since they try to solve versioning using a relational database they require that you setup table for each model being versioned, clutter your main table or serialize your data into a single `TEXT` or `BLOB` field.

Historical doesn't need to look for workarounds since it uses MongoDB as the backend, a document-database which does not require a fixed schema or table structure.


## Rails Version

Developed with/for Rails 3.0, installable using Bundler.


## Usage Example

    # models/message.rb
    
    class Message < ActiveRecord::Base
      # string    :title
      # text      :body
      # datetime  :published_at
      # integer   :author_id
      
      # This is unnecessary if you use Rails (will be installed by default on boot)
      extend Historical::ActiveRecord
      
      is_historical
    end
    
    # app.rb
    
    m = Message.create(:title => "foo", :author_id => 1)
    m.author = Person.find(2)
    m.title = "bar"
    m.save!
    
    versions = m.history.versions.all
    
    # get old values
    versions[0].title       #=> "foo"
    versions[0].author_id   #=> 1
    
    # access an old relation
    old = versions[0].restore     #=> <#Message>
    old.author                    #=> User(id:1)
    
    # what changed?
    versions[1].diff.to_hash      #=> { :author_id => [1, 2], :title => ["foo", "bar"] }
    versions[1].diff.changes      #=> [<#AttributeDiff>, <#AttributeDiff>]
    versions[1].meta.created_at   #=> 2010-01-23 18:56:52 (date when model was saved)
    
    
## Audits (and other Meta-Data)

As you have seen above each version contains a meta-object. You can write custom data to that meta object.

    # YourApp.current_user could be set by a before_filter

    class AuditedMessage < ActiveRecord::Base
    
      # This is unnecessary if you use Rails (will be installed by default on boot)
      extend Historical::ActiveRecord
      
      is_historical do
      
        meta do
          # extend that object with MongoMapper helpers
          key :reason, String
          
          belongs_to_active_record :author, :required => true, :class_name => "Person"
        end

        callback do |version|
          version.meta.author   = YourApp.current_user
          version.meta.reason   = "some reason"
        end
      end
    end
    
    Historical::Models::ModelVersion.where(:"meta.author_id" => 1).all
    
### `belongs_to_active_record`

The MongoMapper extension `belongs_to_active_record` creates `belongs_to` (also polymorphic) relations and will
handle key generation.


## History Model (Quick Overview)

When calling `model.history` you will get a object that contains several methods to operate with the history of a model.
  
 - `model.history.versions` will return a PQ containing all versions for that model. It's sorted ascending by creation date.
 - `model.history.previous_version`, `model.history.next_version`, `model.history.latest_version`, `model.history.original_version` - you get it.
 - `model.history.find_version(2)` like in `model.history.versions.all[2]` only handled by the database (less db-app traffic).
 
### UseCase for `history.next_version`

    old_message = message.history.original_version.restore
    not_so_old_message = old_message.history.next_version.restore

### Note: Plucky Query (PQ)

MongoMapper - which is used by Historical - uses Plucky, a query generator. To perform the query you must call `.all` on it (similar to ActiveRecord).

    
## Interaction with 3rd Party Plugins

Historical won't prevent your model from being destroyed. Should your model be destroyed all versions
will be destroyed as well. However you might consider to use [`is_paranoid`](http://github.com/semanticart/is_paranoid)
by [semanticart](http://github.com/semanticart) for that. Historical will then detect updates on the `deleted_at` column
and store a new version.

**Note:** `is_paranoid` was discontinued by **semanticart** in October 2009. I recommend to
[read about the whys](http://blog.semanticart.com/killing_is_paranoid/). These are also the reasons
why such feature isn't implemented in Historical by itself. You might want to use the
[less hacky `is_paranoid`](http://github.com/mislav/is_paranoid) by [mislav](http://github.com/mislav),
who developed `will_paginate`.


## Intellectual Property

Copyright (c) 2010 Marcel Jackwerth (marcel@northdocks.com). Released under the MIT licence.
