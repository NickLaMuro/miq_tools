`miq_vagrant_master`
====================

This is a helper script for fetching a up to date `vagrant` box for the nightly
`master` build from [http://releases.manageiq.org/][1] in a versioned manner.

Doing this requires creating a `metadata.json` file that vagrant can use to
determine what the available versions are, and where to fetch them.  This is an
example of what this JSON looks like from the `hammer` release from
[https://app.vagrantup.com][2]:

```json
{
  "description":       "ManageIQ Open-Source Management Platform http://manageiq.org",
  "short_description": "ManageIQ Open-Source Management Platform http://manageiq.org",
  "name":              "manageiq/hammer",
  "versions":          [
    {
      "version":              "8.6.0",
      "status":               "active",
      "description_html":     "<p>hammer-6 release</p>\n",
      "description_markdown": "hammer-6 release",
      "providers":            [
        {
          "name":"virtualbox",
          "url":"https://vagrantcloud.com/manageiq/boxes/hammer/versions/8.6.0/providers/virtualbox.box"
        }
      ]
    },
    {
      "version":              "8.5.1",
      "status":               "active",
      "description_html":     "<p>hammer-5.1 release</p>\n",
      "description_markdown": "hammer-5.1 release",
      "providers":            [
        {
          "name": "virtualbox",
          "url":  "https://vagrantcloud.com/manageiq/boxes/hammer/versions/8.5.1/providers/virtualbox.box"
        }
      ]
    },
    ...
  ]
}
```

This tool handles converting the list of master releases for vagrant from
[http://releases.manageiq.org/][1] and converts into a metadata form that
`vagrant` can work with.  This is required to allow incremented versions from
the master builds that aren't from [vagrantup.com][3].


Requirements
------------

- A recent version of `vagrant`
- Ruby


Usage
-----

To fetch the latest master, just run

```console
$ ./miq_vagrant_master/cli
==> box: Loading metadata for box '/tmp/20190702-13714-1ti54l2'
    box: URL: file:///tmp/20190702-13714-1ti54l2
==> box: Adding box 'manageiq/master' (v20190629) for provider: virtualbox
    box: Downloading: http://releases.manageiq.org/manageiq-vagrant-master-20190629-b20592c188.box
    box: Download redirected to host: XXXXXX-XXXXXX.rXX.cXX.rackcdn.com
==> box: Successfully added box 'manageiq/master' (v20190629) for 'virtualbox'!
```

And it will install a box as the `manageiq/master`.  If you want a specific
version, you can either specify a release date:

```console
$ ./miq_vagrant_master/cli --date 20190627
# or
$ ./miq_vagrant_master/cli --version 20190627
==> box: Loading metadata for box '/tmp/20190702-14786-xn9js2'
    box: URL: file:///tmp/20190702-14786-xn9js2
==> box: Adding box 'manageiq/master' (v20190627) for provider: virtualbox
    box: Downloading: http://releases.manageiq.org/manageiq-vagrant-master-20190627-f06ea8cf96.box
    box: Download redirected to host: XXXXXX-XXXXXX.rXX.cXX.rackcdn.com
==> box: Successfully added box 'manageiq/master' (v20190627) for 'virtualbox'!
```

Or a commit SHA:

```console
$ ./miq_vagrant_master/cli --sha f06ea8cf96
# or
$ ./miq_vagrant_master/cli --version f06ea8cf96
==> box: Loading metadata for box '/tmp/20190702-14786-xn9js2'
    box: URL: file:///tmp/20190702-14786-xn9js2
==> box: Adding box 'manageiq/master' (v20190627) for provider: virtualbox
    box: Downloading: http://releases.manageiq.org/manageiq-vagrant-master-20190627-f06ea8cf96.box
    box: Download redirected to host: XXXXXX-XXXXXX.rXX.cXX.rackcdn.com
==> box: Successfully added box 'manageiq/master' (v20190627) for 'virtualbox'!
```

And a proper version of the build will be determined from that.

```console
$ vagrant box list
manageiq/fine            (virtualbox, 6.4.0)
manageiq/gaprindashvili  (virtualbox, 7.3.0)
manageiq/gaprindashvili  (virtualbox, 7.4.0)
manageiq/hammer          (virtualbox, 8.1.0-beta2)
manageiq/hammer          (virtualbox, 8.5.1)
manageiq/hammer          (virtualbox, 8.6.0)
manageiq/master          (virtualbox, 20190627)
manageiq/master          (virtualbox, 20190629)
```

Note:  Because the nightly master builds are not "versioned" like stable
releases, the date is what is used for the version.


[1]: http://releases.manageiq.org/
[2]: https://app.vagrantup.com/manageiq/boxes/hammer.json
[2]: https://app.vagrantup.com
