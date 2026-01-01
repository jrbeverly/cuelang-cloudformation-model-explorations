package invalidref

import "example.com/cuelang-cloudformation-model-explorations:cfmodel"

// A bucket policy whose Bucket binding targets a logical ID that is not
// declared in this template. Everything else resolves: the dangling Ref
// must be rejected at vet as an undefined field.
t: cfmodel.#Template & {
	Resources: {
		Bucket: cfmodel.#Bucket & {}
		BucketPolicy: cfmodel.#BucketPolicy & {
			Properties: {
				Bucket: cfmodel.#Ref & {
					fn:     "Ref"
					target: t.Resources.MissingBucket
				}
				PolicyDocument: cfmodel.#PolicyDocument & {
					Version: "2012-10-17"
					Statement: [cfmodel.#PolicyStatement & {
						Effect:   "Allow"
						Action:   "s3:GetObject"
						Resource: cfmodel.#GetAtt & {
							fn:        "GetAtt"
							resource:  t.Resources.Bucket
							attribute: "Arn"
						}
					}]
				}
			}
		}
	}
}
