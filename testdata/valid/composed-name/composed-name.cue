package composedname

import "example.com/cuelang-cloudformation-model-explorations:cfmodel"

// Composed names whose components each declare provable bounds:
// a Join bounded at 4 + 1 + 3 = 8, and a Sub bounded at 9 + 3 = 12.
t: cfmodel.#Template & {
	Parameters: {
		Env: MaxLength: 3
	}
	Resources: {
		Bucket: cfmodel.#Bucket & {
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
	}
}
