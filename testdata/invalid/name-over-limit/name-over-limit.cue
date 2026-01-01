package nameoverlimit

import "example.com/cuelang-cloudformation-model-explorations:cfmodel"

// A composed name whose declared bounds sum past the S3 limit:
// 32 + 1 + 32 = 65 > 63.
t: cfmodel.#Template & {
	Resources: {
		Bucket: cfmodel.#Bucket & {
			Properties: {
				BucketName: cfmodel.#JoinName & {
					kind:      "join"
					delimiter: "-"
					parts: [
						cfmodel.#LiteralComponent & {kind: "literal", value: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
						cfmodel.#LiteralComponent & {kind: "literal", value: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"},
					]
				}
			}
		}
	}
}
