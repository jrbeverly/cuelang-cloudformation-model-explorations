package unknowngetatt

import "example.com/cuelang-cloudformation-model-explorations:cfmodel"

// A GetAtt to an attribute the referenced resource type does not expose.
t: cfmodel.#Template & {
	Resources: {
		Bucket: cfmodel.#Bucket & {}
		Topic: cfmodel.#Topic & {
			Properties: {
				SourceArn: cfmodel.#GetAtt & {
					fn:        "GetAtt"
					resource:  t.Resources.Bucket
					attribute: "Bogus"
				}
			}
		}
	}
}
