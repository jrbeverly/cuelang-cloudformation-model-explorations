# CUE CloudFormation Model Exploration

> [!WARNING]
> Abandoned repository as part of a series of generic explorations in Cuelang capabilities.

Tests CUE as a constrained model that validates and lowers a small CloudFormation template to JSON.

```sh
./validate.sh
./run.sh
./run.sh testdata/valid/intrinsics
```

## Notes

- Literal and composed S3 bucket names are checked against length and character constraints.
- `Ref` and `GetAtt` targets resolve against resources declared in the same model.
- The model lowers references and selected intrinsic functions to CloudFormation syntax.
- Inputs that cannot prove their bounds are rejected rather than emitted.
- continued Factory issue; excessive Bash scripting, excessive comments, excessive writing, excessive complexity
- implementation is still relatively simple; concern is the recurring pattern
- conceptually nice approach to management configuration + definition of things
- still feels too heavy
- does not feel like it is representing the true model of the underlying system
- feels more like configuration management layered on top of the problem
- with cuelang; concern that we are managing configuration symptoms rather than addressing the root modelling problem
- likely need to rethink the abstraction; model the thing itself first, configuration should fall out of that rather than become the primary system
