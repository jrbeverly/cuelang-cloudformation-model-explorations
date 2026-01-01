package cfmodel

import "list"

// ---------------------------------------------------------------------------
// Semantic model.
//
// #ModelCore is the validated semantic surface: named resources plus optional
// parameters and conditions. Every map binds its key to the entry's _id
// (pattern alias) so references can emit CloudFormation logical IDs.
// #Template extends the core with Template, the CloudFormation lowering.

#ModelCore: {
	Resources: [rname=string]: #Resource & {_id: rname}
	Parameters?: [pname=string]: #Parameter & {_id: pname}
	Conditions?: [cname=string]: #Condition & {_id: cname}
}

#Template: {
	// The model surface (mirrors #ModelCore; redeclared here because
	// unqualified references do not resolve through a definition conjunct
	// in cue v0.17).
	Resources: [rname=string]: #Resource & {_id: rname}
	Parameters?: [pname=string]: #Parameter & {_id: pname}
	Conditions?: [cname=string]: #Condition & {_id: cname}

	// Template lowers this validated model into CloudFormation structure.
	// It is derived entirely by unification: emission never constructs
	// anything the model has not already validated.
	//
	// The model core is mirrored into the lowering through hidden bridge
	// fields: a nested literal cannot reference its own enclosing fields by
	// name in cue v0.17, and the separate definition keeps the lowering's
	// comprehensions out of the model's own evaluation.
	_resources: Resources
	_params: *Parameters | {}
	_conditions: *Conditions | {}

	Template: #LoweredTemplate & {
		_model: {
			Resources:  _resources
			Parameters: _params
			Conditions: _conditions
		}
	}
}

// #LoweredTemplate holds the CloudFormation form of a model. The model is
// carried in a hidden field (rather than extended directly) so the lowering
// never participates in the model's own evaluation.
#LoweredTemplate: {
	_model: #ModelCore

	Resources: {for k, r in _model.Resources {
		"\(k)": {
			Type: r.Type
			Properties: {for pk, pv in r.Properties {"\(pk)": pv.Template}}
		}
	}}
	if _model.Parameters != {} {
		Parameters: {for k, p in _model.Parameters {"\(k)": p.Template}}
	}
	if _model.Conditions != {} {
		Conditions: {for k, c in _model.Conditions {"\(k)": c.Template}}
	}
}

// #Resource is the base of every resource type.
#Resource: {
	Type: string
	// Properties stay open: every value must still be a construct the model
	// can lower, because the lowering accesses each value's Template field
	// (a non-lowerable value fails vet). Typing the values would create a
	// constraint cycle (#Value -> #Ref -> #Resource -> #Value) that the cue
	// evaluator cannot resolve.
	Properties: {...}
	Attributes: {...}
	// _id is the CloudFormation logical ID, bound to the resource's map key
	// by the pattern in #ModelCore.Resources.
	_id: string
}

// #Parameter declares a template parameter. For a parameter to participate in
// a provably safe composed name it must declare MaxLength.
#Parameter: {
	Type:      "String"
	MaxLength: int
	// _id is the logical ID, bound to the parameter's map key by the pattern
	// in #ModelCore.Parameters.
	_id: string
	// _maxLength bridges MaxLength into Template: a nested literal cannot
	// reference its own enclosing field by name in cue v0.17.
	_maxLength: MaxLength
	Template: {
		Type:      "String"
		MaxLength: _maxLength
	}
}

// ---------------------------------------------------------------------------
// Constraint group 1: provable name safety.
//
// A bucket name is a #Name expression: a literal, a Sub composition, or a
// Join composition. Every form carries a provable maximum length. A literal
// must satisfy the S3 charset rule; a composition must supply a bound on
// every component so the resulting maximum length is checkable. An unbounded
// or over-limit name is rejected at vet time.

#Name: #LiteralName | #SubName | #JoinName

#LiteralName: {
	kind: "literal"
	// S3 charset: lowercase letters, digits, dots and hyphens; must start
	// and end alphanumeric; 3..63 characters; no adjacent dots.
	value:    =~"^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$"
	value:    !~"\\.\\."
	maxLen:   len(value)
	maxLen:   <=63
	maxLen:   >=3
	Template: value
}

#NameComponent: #LiteralComponent | #RefComponent

#LiteralComponent: {
	kind:     "literal"
	value:    =~"^[a-z0-9.-]+$"
	maxLen:   len(value)
	Template: value
}

#RefComponent: {
	kind:   "ref"
	target: #Parameter
	// The component bound must be declared and must not exceed the
	// referenced parameter's own declared bound.
	maxLen: int & >=0 & <=target.MaxLength
	Template: {"Ref": target._id}
}

#SubName: {
	kind:     "sub"
	template: string
	components: [...#NameComponent]
	// Upper bound: template text plus each component at its declared max.
	maxLen: len(template) + list.Sum([for c in components {c.maxLen}])
	maxLen: <=63
	maxLen: >=3
	// The plain-string form: ${Var} placeholders resolve against the
	// template's Parameters at deploy time. (Validating that every
	// placeholder corresponds to a declared component is deferred.)
	Template: {"Fn::Sub": template}
}

#JoinName: {
	kind:      "join"
	delimiter: =~"^[a-z0-9.-]{1,63}$"
	parts: [#NameComponent, ...#NameComponent]
	// Upper bound: delimiters plus each part at its declared max.
	maxLen: (len(parts)-1)*len(delimiter) + list.Sum([for p in parts {p.maxLen}])
	maxLen: <=63
	maxLen: >=3
	Template: {"Fn::Join": [delimiter, [for p in parts {p.Template}]]}
}

// ---------------------------------------------------------------------------
// Constraint group 2: reference resolution.
//
// A Ref/GetAtt binds its target to the actual resource value declared in the
// same template, so a dangling logical ID is an undefined-field error at vet
// time. A GetAtt additionally resolves its attribute against the closed
// attribute set of the referenced resource type.

#Ref: {
	fn:     "Ref"
	target: #Resource
	Template: {"Ref": target._id}
}

#GetAtt: {
	fn:       "GetAtt"
	resource: #Resource
	// attribute must be one of the attributes the resource type exposes:
	// the lookup fails when the attribute is not a field of the closed
	// Attributes struct of the referenced resource.
	attribute: string & resource.Attributes[attribute]
	Template: {"Fn::GetAtt": [resource._id, attribute]}
}

// ---------------------------------------------------------------------------
// Constraint group 3: conditions.
//
// A condition expression is an Equals or a Not; an If selects between two
// values by naming a condition declared in the same template. The named
// condition must exist: it is bound to the actual condition value, so a
// dangling condition name is an undefined-field error at vet time.

// #Condition is a single guarded definition rather than a disjunction of
// members: disjunction members cannot reference each other's lowering in cue
// v0.17 (branch elimination fails).
#Condition: {
	kind: "equals" | "not"
	// _id is the logical ID, bound to the condition's map key by the pattern
	// in #ModelCore.Conditions.
	_id: string
	// The kind-specific fields are declared optional and required by guard:
	// fields declared only under a guard cannot be referenced elsewhere.
	lhs?:     #ConditionOperand
	rhs?:     #ConditionOperand
	operand?: #Condition
	if kind == "equals" {
		lhs: #ConditionOperand
		rhs: #ConditionOperand
	}
	if kind == "not" {
		operand: #Condition
	}
	Template: {
		if kind == "equals" {
			"Fn::Equals": [lhs.Template, rhs.Template]
		}
		if kind == "not" {
			"Fn::Not": [operand.Template]
		}
	}
}

// The branches exclude #GetAtt and nested Ifs: the closed-set attribute
// lookup in #GetAtt defeats disjunction resolution in cue v0.17, so GetAtt
// may only appear standalone. A GetAtt or nested If branch is deferred.
#If: {
	fn:        "If"
	condition: #Condition
	ifTrue:    #Name | #Ref
	ifFalse:   #Name | #Ref
	Template: {"Fn::If": [condition._id, ifTrue.Template, ifFalse.Template]}
}

#ConditionOperand: #LiteralString | #ParamRef

#LiteralString: {
	kind:     *"literal" | "literal"
	value:    string
	Template: value
}

// #ParamRef references a template parameter. It is the condition-operand
// counterpart of #RefComponent (which carries name-bound metadata).
#ParamRef: {
	fn:     *"Ref" | "Ref"
	target: #Parameter
	Template: {"Ref": target._id}
}

// --- resource types ---

#Bucket: #Resource & {
	Type: "AWS::S3::Bucket"
	Properties: {
		BucketName?: #Name
	}
	Attributes: close({
		Arn:                 "Arn"
		DomainName:          "DomainName"
		RegionalDomainName:  "RegionalDomainName"
		WebsiteURL:          "WebsiteURL"
		DualStackDomainName: "DualStackDomainName"
	})
}

#Topic: #Resource & {
	Type: "AWS::SNS::Topic"
	Properties: {
		TopicName?: #Name
	}
	Attributes: close({
		TopicName: "TopicName"
	})
}

// --- bucket policy ---
//
// A bucket policy attaches a policy document to a bucket declared in the
// same template. Bucket binds to the actual bucket resource (a dangling
// logical ID is an undefined-field error at vet time), and the document's
// statements carry a closed Effect set plus a Resource that must be a
// construct the model can lower — in the worked example, a GetAtt of the
// bucket's Arn.

#BucketPolicy: #Resource & {
	Type: "AWS::S3::BucketPolicy"
	Properties: {
		Bucket:         #Ref
		PolicyDocument: #PolicyDocument
	}
	Attributes: close({})
}

// Statement.Resource is deliberately not typed as a disjunction of
// constructs: the closed-set attribute lookup in #GetAtt defeats disjunction
// resolution in cue v0.17, so a policy resource written as a GetAtt may only
// appear standalone (the same boundary as #If's branches). Lowerability is
// still enforced at vet: the lowering accesses Resource.Template, so a value
// without a Template field (for example a raw string) fails vet.
#PolicyDocument: {
	Version:   "2012-10-17"
	Statement: [...#PolicyStatement]
	// Hidden bridges: a nested literal cannot reference its own enclosing
	// fields by name in cue v0.17.
	_version:   Version
	_statement: Statement
	Template: {
		Version:   _version
		Statement: [for s in _statement {s.Template}]
	}
}

#PolicyStatement: {
	Effect: "Allow" | "Deny"
	Action: string | [string, ...string]
	// Resource is constrained to the bare top rather than a struct literal:
	// constraining it to a struct shape breaks the placement of reference
	// constructs (Ref/GetAtt) in cue v0.17. Lowerability is still enforced
	// at vet: the lowering accesses Resource.Template.
	Resource: _
	// Hidden bridges, as in #PolicyDocument above.
	_effect:   Effect
	_action:   Action
	_resource: Resource
	Template: {
		Effect:   _effect
		Action:   _action
		Resource: _resource.Template
	}
}
