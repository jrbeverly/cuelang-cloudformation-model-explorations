package valid

import "example.com/cuelang-cloudformation-model-explorations:cfmodel"

// The worked valid example: a bucket whose literal name is provably within
// the S3 charset and length rules, and a bucket policy whose Bucket binding
// and statement Resource both resolve to that bucket (Ref -> the logical ID,
// GetAtt -> the bucket's Arn).
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
		BucketPolicy: cfmodel.#BucketPolicy & {
			Properties: {
				Bucket: cfmodel.#Ref & {
					fn:     "Ref"
					target: t.Resources.Bucket
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

// Emission surface: run.sh exports -e Template.
Template: t.Template
