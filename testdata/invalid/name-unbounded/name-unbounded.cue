package nameunbounded

import "example.com/cuelang-cloudformation-model-explorations:cfmodel"

// A composed name with a ref component that declares no length bound:
// the resulting maximum length is not provable and must be rejected.
t: cfmodel.#Template & {
	Parameters: {
		Env: MaxLength: 12
	}
	Resources: {
		Bucket: cfmodel.#Bucket & {
			Properties: {
				BucketName: cfmodel.#JoinName & {
					kind:      "join"
					delimiter: "-"
					parts: [
						cfmodel.#LiteralComponent & {kind: "literal", value: "data"},
						cfmodel.#RefComponent & {kind: "ref", target: t.Parameters.Env},
					]
				}
			}
		}
	}
}
