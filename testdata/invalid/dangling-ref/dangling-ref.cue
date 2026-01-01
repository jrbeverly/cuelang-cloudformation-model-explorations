package danglingref

import "example.com/cuelang-cloudformation-model-explorations:cfmodel"

// A Ref to a resource that is not declared in this template.
t: cfmodel.#Template & {
	Resources: {
		Topic: cfmodel.#Topic & {
			Properties: {
				Source: cfmodel.#Ref & {
					fn:     "Ref"
					target: t.Resources.MissingBucket
				}
			}
		}
	}
}
