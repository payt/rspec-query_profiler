# rspec-query_profiler

Tracks how many database queries it takes to complete an example.

# Usage

```console
PROFILE=1 rspec spec/users/destroy_spec.rb

# subject(:call) -> query count: 2
```

When you need more details:

```console
PROFILE=2 rspec spec/users/destroy_spec.rb

# subject(:call) -> query count: 2
# - (1): 'User Load' -> SELECT "users".* FROM "users" WHERE "users"."id" = $1 LIMIT $2 [[15, 1]]
# - (1): 'User Destroy' -> DELETE FROM "users" WHERE "users"."id" = $1 [[15]]
```

### Features
- It does not log queries triggered during any of RSpec callbacks.
- It knows about FactoryBot, skipping queries that are triggered by it.

### Known limitations 
- It will log queries that are triggered after the subject is called, that are within a regular `let` and that do not use FactoryBot. False positive for: `let(:user) { User.take }`
- It treats the `subject` as something special. RSpec doesn't care if you use `let` instead of `subject` in your specs, this gem does.

### Todo
- Track queries triggered by the spec setup separatly. Can be used to improve the testsuite itself.
- Create a diffable log of all queries which can be checked in the repo to be able to track changes
