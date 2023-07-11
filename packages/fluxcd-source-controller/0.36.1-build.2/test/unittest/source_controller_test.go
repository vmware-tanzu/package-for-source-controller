/*
Copyright © 2022 VMware, Inc. All rights reserved.

Proprietary and confidential.

Unauthorized copying or use of this file, in any medium or form,
is strictly prohibited.
*/

package sourcecontroller

import (
	"io/ioutil"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/vmware-tanzu/community-edition/addons/packages/test/pkg/ytt"
)

func TestRenderingOfPackage(t *testing.T) {
	var filePaths []string

	configDir := filepath.Join("../../bundle/config")

	for _, p := range []string{"upstream/**/**/*.yaml", "upstream/**/*.yaml", "overlays/*.yaml", "*.yaml", "*.star"} {
		matches, err := filepath.Glob(filepath.Join(configDir, p))
		require.NoError(t, err)

		filePaths = append(filePaths, matches...)
	}

	values, err := ioutil.ReadFile(filepath.Join("fixtures/values", "default.yaml"))
	require.NoError(t, err)

	output, err := ytt.RenderYTTTemplate(ytt.CommandOptions{}, filePaths, strings.NewReader(string(values)))
	require.NoError(t, err)

	expectedData, err := ioutil.ReadFile(filepath.Join("fixtures/expected", "default.yaml"))
	require.NoError(t, err)

	require.Equal(t, string(expectedData), output)
}
