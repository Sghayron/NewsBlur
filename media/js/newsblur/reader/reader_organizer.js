NEWSBLUR.ReaderOrganizer = function(user_id, options) {
    var defaults = {
        width: 800,
        sorting: 'alphabetical',
        onOpen: _.bind(function() {
            this.resize_modal();
        }, this),
        hierarchy: "nested",
        inverse_sorting: false
    };
        
    this.options = $.extend({}, defaults, options);
    this.model   = NEWSBLUR.assets;
    this.init();
};

NEWSBLUR.ReaderOrganizer.prototype = new NEWSBLUR.Modal;

_.extend(NEWSBLUR.ReaderOrganizer.prototype, {
    
    init: function() {
        this.reset_feeds();
        this.make_modal();
        this.open_modal();

        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    reset_feeds: function() {
        NEWSBLUR.assets.feeds.each(function(feed) {
            feed.highlight_in_all_folders(false, true, {silent: true});
        });
    },
    
    make_modal: function() {
        var self = this;

        this.$modal = $.make('div', { className: 'NB-modal NB-modal-organizer' }, [
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-modal-loading' }),
                $.make('div', { className: 'NB-icon' }),
                'Organize sites',
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            $.make('div', { className: 'NB-organizer-sidebar'}, [
                $.make('div', { className: 'NB-organizer-sidebar-hierarchy' }, [
                    $.make('div', { className: 'NB-organizer-sidebar-title' }, 'Show Folders'),
                    $.make('div', { className: 'NB-organizer-sidebar-container' }, [
                        $.make('ul', { className: 'segmented-control' }, [
                            $.make('li', { className: 'NB-organizer-hierarchy NB-organizer-hierarchy-nested NB-active' }, 'Nested'),
                            $.make('li', { className: 'NB-organizer-hierarchy NB-organizer-hierarchy-flat' }, 'Flat')
                        ])                        
                    ])
                ]),
                $.make('div', { className: 'NB-organizer-sidebar-move' }, [
                    $.make('div', { className: 'NB-organizer-sidebar-title' }, 'Move to folder'),
                    $.make('div', { className: 'NB-organizer-sidebar-container' }, [
                        NEWSBLUR.utils.make_folders(),
                        $.make('div', { className: 'NB-icon-add', title: "Add folder" }),
                        $.make('div', { className: "NB-add-folder NB-hidden" }, [
                            $.make('div', { className: 'NB-icon-subfolder' }),
                            $.make('input', { type: 'text', id: 'NB-add-folder', className: 'NB-input NB-add-folder-input', name: 'new_folder_name', placeholder: "New folder name..." })
                        ]),
                        $.make('div', { className: 'NB-error-move NB-error' }),
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green NB-disabled NB-action-move' }, 'Move'),
                        $.make('div', { className: 'NB-loading' })
                    ])
                ]),
                $.make('div', { className: 'NB-organizer-sidebar-delete' }, [
                    $.make('div', { className: 'NB-organizer-sidebar-title' }, 'Delete sites'),
                    $.make('div', { className: 'NB-organizer-sidebar-container' }, [
                        $.make('div', { className: 'NB-error-delete NB-error' }),
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-red NB-disabled NB-action-delete' }, 'Delete'),
                        $.make('div', { className: 'NB-loading' })
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-organizer-actionbar' }, [
                $.make('div', { className: 'NB-organizer-sorts' }, [
                    $.make('div', { className: 'NB-organizer-action-title' }, 'Sort '),
                    $.make('div', { className: 'NB-organizer-action NB-action-alphabetical NB-active' }, 'Name'),
                    $.make('div', { className: 'NB-organizer-action NB-action-subscribers' }, 'Subscribers'),
                    $.make('div', { className: 'NB-organizer-action NB-action-frequency' }, 'Frequency'),
                    $.make('div', { className: 'NB-organizer-action NB-action-recency' }, 'Recency'),
                    $.make('div', { className: 'NB-organizer-action NB-action-mostused' }, 'Opens')
                ]),
                $.make('div', { className: 'NB-organizer-selects' }, [
                    $.make('div', { className: 'NB-organizer-action-title' }, 'Select'),
                    $.make('div', { className: 'NB-organizer-action NB-action-select-all' }, 'All'),
                    $.make('div', { className: 'NB-organizer-action NB-action-select-none' }, 'None')
                ])
            ]),
            this.make_feeds()
        ]);
    },
    
    resize_modal: function(previous_height) {
        var resize_height = 0;
        var $feedlist = $('.NB-feedchooser', this.$modal);
        var content_height = $feedlist.height() + 90;
        var container_height = this.$modal.parent().height();
        if (content_height > container_height && previous_height != content_height) {
            var chooser_height = $feedlist.height();
            var diff = Math.max(4, content_height - container_height);
            resize_height = chooser_height - diff;
            $feedlist.css({'max-height': resize_height});
            _.defer(_.bind(function() { this.resize_modal(content_height); }, this), 1);
        }
        if (resize_height) {
            this.options.resize = resize_height;
        }
    },
    
    // =============
    // = Feed list =
    // =============
    
    make_feeds: function(options) {
        var feeds = this.model.feeds;
        if (this.options.hierarchy == "flat") {
            this.options.folders = new NEWSBLUR.Collections.Folders(NEWSBLUR.assets.feeds.pluck('id'));
        } else {
            this.options.folders = NEWSBLUR.assets.folders;
        }
        this.feed_count = _.unique(this.options.folders.feed_ids_in_folder()).length;
        NEWSBLUR.Collections.Folders.organizer_sortorder = this.options.sorting;
        NEWSBLUR.Collections.Folders.organizer_inversesort = this.options.inverse_sorting;
        this.options.folders.sort();
        
        this.feedlist = new NEWSBLUR.Views.FeedList({
            feed_chooser: true,
            organizer: true,
            hierarchy: this.options.hierarchy,
            sorting: this.options.sorting,
            inverse_sorting: this.options.inverse_sorting
        }).make_feeds({folders: this.options.folders});
        var $feeds = this.feedlist.$el;
        if (this.options.resize) {
            $feeds.css({'max-height': this.options.resize});
        }
        if ($feeds.data('sortable')) $feeds.data('sortable').disable();
        
        // Expand collapsed folders
        $('.NB-folder-collapsed', $feeds).css({
            'display': 'block',
            'opacity': 1
        }).removeClass('NB-folder-collapsed');
        
        // Pretend unfetched feeds are fine
        $('.NB-feed-unfetched', $feeds).removeClass('NB-feed-unfetched');

        // Make sure all folders are visible
        $('.NB-folder.NB-hidden', $feeds).removeClass('NB-hidden');
        
        $('.NB-organizer-sorts', this.$modal).toggleClass('NB-sort-inverse', this.options.inverse_sorting);
        
        NEWSBLUR.Collections.Folders.organizer_sortorder = null;
        this.options.folders.sort();

        NEWSBLUR.assets.feeds.off('change:highlighted')
                             .on('change:highlighted', _.bind(this.change_selection, this));
        
        return $feeds;
    },
    
    // =============
    // = Selecting =
    // =============
    
    change_select: function(select) {
        if (select == "all") {
            this.feedlist.folder_view.highlight_feeds({force_highlight: true});
        } else if (select == "none") {
            this.feedlist.folder_view.highlight_feeds({force_deselect: true});
        }
    },
    
    change_selection: function() {
        var $title = $(".NB-organizer-selects .NB-organizer-action-title", this.$modal);
        var $move = $(".NB-action-move", this.$modal);
        var $error = $(".NB-error-move", this.$modal);
        var $delete = $(".NB-action-delete", this.$modal);
        var count = this.feedlist.folder_view.highlighted_count_unique_folders();

        $title.text(count ? count + " selected" : "Select");
        $error.text('');
        
        if (!count) {
            $delete.text('Delete').addClass('NB-disabled');
            $move.text('Move').addClass('NB-disabled');
        } else {
            $delete.text('Delete ' + Inflector.pluralize('site', count, true)).removeClass('NB-disabled');
            $move.text('Move ' + Inflector.pluralize('site', count, true)).removeClass('NB-disabled');
        }
    },
    
    // ===========
    // = Sorting =
    // ===========
    
    change_sort: function(sorting) {
        var inverse = this.options.inverse_sorting;
        if (this.options.sorting == sorting) {
            this.options.inverse_sorting = !inverse;
        } else {
            this.options.inverse_sorting = false;
        }
        this.options.sorting = sorting;
        
        $(".NB-action-"+sorting, this.$modal).addClass('NB-active').siblings().removeClass('NB-active');

        $(".NB-feedlist", this.$modal).replaceWith(this.make_feeds());
    },
    
    // =============
    // = Hierarchy =
    // =============
    
    toggle_hierarchy: function(hierarchy) {
        this.options.hierarchy = hierarchy;
        $(".NB-organizer-hierarchy", this.$modal).removeClass('NB-active');
        $(".NB-organizer-hierarchy-"+hierarchy, this.$modal).addClass('NB-active');
        
        $(".NB-feedlist", this.$modal).replaceWith(this.make_feeds());
    },
    
    // ==========
    // = Server =
    // ==========
    
    serialize: function() {
        var highlighted_feeds = this.feedlist.folder_view.highlighted_feeds({
            collection: this.options.folders
        });
        
        return highlighted_feeds;
    },
    
    move_feeds: function() {
        var self = this;
        var highlighted_feeds = this.serialize();
        var $move = $('.NB-action-move', this.$modal);
        var $error = $(".NB-error-move", this.$modal).hide();
        var $loading = $('.NB-modal-loading', this.$modal);
        var new_folder = $('.NB-add-folder-input', this.$modal).val();
        var $feedlist = $(".NB-feedlist", this.$modal);
        var to_folder = $('.NB-folders').val();
        $loading.addClass('NB-active');
        $move.addClass('NB-disabled').text('Moving...');
        NEWSBLUR.reader.flags['reloading_feeds'] = true;
        
        if (!this._open_folder) new_folder = null;
        
        console.log(["Moving feeds by folder", highlighted_feeds, to_folder, new_folder]);

        NEWSBLUR.assets.move_feeds_by_folder(highlighted_feeds, to_folder, new_folder, function() {
            NEWSBLUR.reader.flags['reloading_feeds'] = false;
            $loading.removeClass('NB-active');
            self.reset_feeds();
            $feedlist.replaceWith(self.make_feeds());
            self.change_selection();
            NEWSBLUR.assets.feeds.trigger('reset');
            $move.text('Moved!');
            if (self._open_folder) self.toggle_folder_add();
        }, function(error) {
            NEWSBLUR.reader.flags['reloading_feeds'] = false;
            $loading.removeClass('NB-active');
            self.change_selection();
            $error.show().text("Sorry, there was a problem moving feeds.");
        });
    },
    
    delete_feeds: function() {
        var self = this;
        var highlighted_feeds = this.serialize();
        var $loading = $('.NB-modal-loading', this.$modal);
        var $error = $(".NB-error-delete", this.$modal).hide();
        var $delete = $('.NB-action-delete', this.$modal);
        var $feedlist = $(".NB-feedlist", this.$modal);
        $loading.addClass('NB-active');
        $delete.addClass('NB-disabled').text('Deleting...');
        NEWSBLUR.reader.flags['reloading_feeds'] = true;

        console.log(["Deleting feeds by folder", highlighted_feeds]);
        
        NEWSBLUR.assets.delete_feeds_by_folder(highlighted_feeds, function() {
            NEWSBLUR.reader.flags['reloading_feeds'] = false;
            $loading.removeClass('NB-active');
            self.reset_feeds();
            $feedlist.replaceWith(self.make_feeds());
            self.change_selection();
            NEWSBLUR.assets.feeds.trigger('reset');
            $delete.text('Deleted!');
            if (self._open_folder) self.toggle_folder_add();
        }, function(error) {
            NEWSBLUR.reader.flags['reloading_feeds'] = false;
            $loading.removeClass('NB-active');
            self.change_selection();
            $error.show().text("Sorry, there was a problem deleting feeds.");
        });
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-organizer-action', childOf: '.NB-organizer-sorts' },
                   _.bind(function($t, $p) {
            e.preventDefault();
            
            var sort = $t.attr('class').match(/\bNB-action-(\w+)\b/)[1];
            this.change_sort(sort);
        }, this));
        
        $.targetIs(e, { tagSelector: '.NB-organizer-action', childOf: '.NB-organizer-selects' },
                   _.bind(function($t, $p) {
            e.preventDefault();
            
            var select = $t.attr('class').match(/\bNB-action-select-(\w+)\b/)[1];
            this.change_select(select);
        }, this));

        $.targetIs(e, { tagSelector: '.NB-organizer-hierarchy' },
                   _.bind(function($t, $p) {
            e.preventDefault();

            var hierarchy = $t.hasClass('NB-organizer-hierarchy-nested') ? 'nested' : 'flat';
            if (this.options.hierarchy == hierarchy) return;

            this.toggle_hierarchy(hierarchy);
        }, this));

        $.targetIs(e, { tagSelector: '.NB-icon-add' },
                   _.bind(function($t, $p) {
            e.preventDefault();
            
            this.toggle_folder_add();
        }, this));
        
        $.targetIs(e, { tagSelector: '.NB-action-move' },
                   _.bind(function($t, $p) {
            e.preventDefault();
            
            if ($t.is('.NB-disabled')) return;
            this.move_feeds();
        }, this));
        
        $.targetIs(e, { tagSelector: '.NB-action-delete' },
                   _.bind(function($t, $p) {
            e.preventDefault();
            
            if ($t.is('.NB-disabled')) return;
            this.delete_feeds();
        }, this));
    },

    toggle_folder_add: function() {
        var $folder = $(".NB-add-folder", this.$modal);
        var $icon = $(".NB-icon-add", this.$modal);

        if (this._open_folder) {
            $folder.slideUp(300);
            $icon.removeClass('NB-active');
            this._open_folder = false;
        } else {
            this._open_folder = true;
            $icon.addClass('NB-active');
            $folder.slideDown(300);
        }
    }
    
});
