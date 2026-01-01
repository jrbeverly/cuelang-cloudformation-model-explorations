package intrinsics

import "example.com/cuelang-cloudformation-model-explorations:cfmodel"

// Every modelled intrinsic in one validated instance: literal, Sub and Join
// names; Ref and GetAtt relationships; and an Fn::If selection driven by
// Fn::Equals / Fn::Not conditions over a template parameter.
t: cfmodel.#Template & {
	Parameters: {
		Env: MaxLength: 3
	}
	Conditions: {
		IsProd: cfmodel.#Condition & {
			kind: "equals"
			lhs: cfmodel.#ParamRef & {
				target: t.Parameters.Env
			}
			rhs: cfmodel.#LiteralString & {
				value: "prod"
			}
		}
		IsNotProd: cfmodel.#Condition & {
			kind:    "not"
			operand: t.Conditions.IsProd
		}
	}
	Resources: {
		Bucket: cfmodel.#Bucket & {
			Properties: {
				BucketName: cfmodel.#LiteralName & {
					kind:  "literal"
					value: "demo-bucket-1234"
				}
			}
		}
		SubBucket: cfmodel.#Bucket & {
			Properties: {
				BucketName: cfmodel.#SubName & {
					kind:     "sub"
					template: "store-${Env}"
					components: [
						cfmodel.#RefComponent & {kind: "ref", target: t.Parameters.Env, maxLen: 3},
					]
				}
			}
		}
		JoinBucket: cfmodel.#Bucket & {
			Properties: {
				BucketName: cfmodel.#JoinName & {
					kind:      "join"
					delimiter: "-"
					parts: [
						cfmodel.#LiteralComponent & {kind: "literal", value: "data"},
						cfmodel.#RefComponent & {kind: "ref", target: t.Parameters.Env, maxLen: 3},
					]
				}
			}
		}
		Topic: cfmodel.#Topic & {
			Properties: {
				TopicName: cfmodel.#LiteralName & {
					kind:  "literal"
					value: "demo-topic"
				}
				Source: cfmodel.#Ref & {
					fn:     "Ref"
					target: t.Resources.Bucket
				}
				SourceArn: cfmodel.#GetAtt & {
					fn:        "GetAtt"
					resource:  t.Resources.Bucket
					attribute: "Arn"
				}
				// Illustrative conditional selection between two declared
				// resources, gated on the IsProd condition.
				SelectedSource: cfmodel.#If & {
					fn:        "If"
					condition: t.Conditions.IsProd
					ifTrue: cfmodel.#Ref & {
						fn:     "Ref"
						target: t.Resources.SubBucket
					}
					ifFalse: cfmodel.#Ref & {
						fn:     "Ref"
						target: t.Resources.JoinBucket
					}
				}
			}
		}
	}
}

// Emission surface: run.sh exports -e Template.
Template: t.Template
