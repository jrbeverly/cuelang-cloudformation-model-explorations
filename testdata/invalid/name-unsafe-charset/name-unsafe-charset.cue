package nameunsafecharset

import "example.com/cuelang-cloudformation-model-explorations:cfmodel"

// A literal name that violates the S3 charset rule.
t: cfmodel.#Template & {
	Resources: {
		Bucket: cfmodel.#Bucket & {
			Properties: {
				BucketName: cfmodel.#LiteralName & {
					kind:  "literal"
					value: "Demo_Bucket!"
				}
			}
		}
	}
}
