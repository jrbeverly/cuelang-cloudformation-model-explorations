package references

import "example.com/cuelang-cloudformation-model-explorations:cfmodel"

// Valid relationships: a Ref and a GetAtt both resolve to the declared
// bucket, and GetAtt names a known bucket attribute.
t: cfmodel.#Template & {
	Resources: {
		Bucket: cfmodel.#Bucket & {
			Properties: {
				BucketName: cfmodel.#LiteralName & {
					kind:  "literal"
					value: "demo-bucket-1234"
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
			}
		}
	}
}
