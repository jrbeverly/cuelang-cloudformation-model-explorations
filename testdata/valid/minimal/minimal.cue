package minimal

import "example.com/cuelang-cloudformation-model-explorations:cfmodel"

// The minimal valid instance: a bucket with a provably safe literal name.
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
	}
}
